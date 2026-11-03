//! trace.rs — harness trace-syscalls: measure the syscall footprint on the
//! 9front donor kernel (port of trace-syscalls.py; Task 2 of the plan).
//!
//! Pipeline (Phase-2 harness discipline throughout):
//!   1. compile build/aarch64/tracehello.c with Harvey's vendored 7c/7l in
//!      the lima guest's Harvey namespace (nsrun.sh --wrap)
//!   2. stage tracehello + the rc trace loop into the guest donor tree's
//!      CONF=qemu bootdir and rebake the donor kernel
//!   3. boot 9qemu-trace.u with the run-gate.sh qemu invocation, drive to
//!      the rc shell (shared console.rs boot drive)
//!   4. trace: launch /boot/tracehello backgrounded, capture $apid, run
//!      /boot/trace.rc (the RESEARCH.md D-14 startsyscall recipe)
//!   5. parse the ENTRY fragments host-side, resolve names against
//!      sys/src/libc/9syscall/sys.h, write the artifact
//!
//! usage: harness trace-syscalls [--boot-chain] [--help]

use std::collections::{HashMap, HashSet};

pub const DONOR_SHA: &str = "350266104f1fed81c78c3d05fa44f523bec0ae4d";

// ---------------------------------------------------------------------------
// Pure parsing core (unit-tested; the live driver feeds it captured bytes)
// ---------------------------------------------------------------------------

/// Load sys/src/libc/9syscall/sys.h #define table, names lowercased
/// (the donor sysctab lowercases and strips the trailing underscore).
pub fn load_sysh(text: &str) -> HashMap<String, u32> {
    let mut defines = HashMap::new();
    for line in text.lines() {
        let mut it = line.split_whitespace();
        match (it.next(), it.next(), it.next()) {
            (Some("#define"), Some(name), Some(num)) => {
                if let Ok(n) = num.parse::<u32>() {
                    defines.insert(name.to_lowercase(), n);
                }
            }
            _ => continue,
        }
    }
    defines
}

/// Resolve a traced syscall name to (number, sys.h name): try name,
/// name+'_', '_'+name (the donor's "brk" is Harvey's BRK_).
pub fn resolve(defines: &HashMap<String, u32>, name: &str) -> Option<(u32, String)> {
    for cand in [
        name.to_string(),
        format!("{}_", name),
        format!("_{}", name),
    ] {
        if let Some(n) = defines.get(&cand) {
            return Some((*n, cand));
        }
    }
    None
}

/// The syscallfmt entry fragment shape: "<pid> <text> <name> <pc> <args…>"
/// with the pc as BARE hex and possibly the last field (end-of-line case).
/// Return fragments beginning " = " never match.
pub fn entry_re() -> crate::regex::Regex {
    crate::regex::Regex::new("^(\\d+) (\\S+) (\\S+) ([0-9a-f]+)(?:\\s|$)").unwrap()
}

/// Parse the hello-path trace region (between the "rc /boot/trace.rc"
/// command echo and the __GSD_TRACE_LOOP_DONE__ marker). Returns
/// (number, sys.h name) pairs in first-use order.
pub fn parse_hello_region(
    region: &str,
    defines: &HashMap<String, u32>,
) -> Result<Vec<(u32, String)>, String> {
    let rx = entry_re();
    let mut ordered: Vec<(u32, String)> = Vec::new();
    let mut seen: HashSet<String> = HashSet::new();
    for line in region.lines() {
        let line = line.trim();
        let Some(m) = rx.find(line.as_bytes()) else {
            continue;
        };
        let name = m.group_str(3, line.as_bytes()).unwrap_or("");
        if name == "huh?" {
            return Err("donor emitted 'huh?' — an unknown syscall number was traced".into());
        }
        let Some((number, sysh_name)) = resolve(defines, &name.to_lowercase()) else {
            return Err(format!(
                "unknown syscall name: {} (no matching #define in sys.h)",
                name
            ));
        };
        if seen.insert(sysh_name.clone()) {
            ordered.push((number, sysh_name));
        }
    }
    if ordered.is_empty() {
        return Err("no entry fragments parsed — /proc/N/syscall surprised; \
                    the D-14 fallback (dosyscall print patch) is required"
            .into());
    }
    let names: HashSet<&str> = ordered.iter().map(|(_, n)| n.as_str()).collect();
    for required in ["pwrite", "exits"] {
        if !names.contains(required) {
            return Err(format!(
                "measured set lacks {} — the trace did not cover the hello path",
                required
            ));
        }
    }
    Ok(ordered)
}

/// Hello-path artifact text (byte-shape of 04-01-d14-trace.txt).
pub fn artifact_hello(ordered: &[(u32, String)], runlog: &str, now_iso: &str) -> String {
    let mut s = String::new();
    s.push_str(&format!("# date: {}\n", now_iso));
    s.push_str(&format!("# donor pin: {} (9front branch front)\n", DONOR_SHA));
    s.push_str("# target: /boot/tracehello (build/aarch64/tracehello.c, vendored 7c/7l in the lima guest namespace)\n");
    s.push_str("# method: startsyscall+/proc/N/syscall (primary; RESEARCH.md D-14)\n");
    s.push_str(&format!(
        "# serial log: {} (gitignored .build evidence)\n",
        runlog
    ));
    for (number, name) in ordered {
        s.push_str(&format!("{} {}\n", number, name));
    }
    s
}

/// The boot-chain parse: role map from the guest driver's arm markers,
/// sweep brackets, tagged-fragment ENTRY parse with per-role and per-name
/// counts, the boot pid's stream.
#[derive(Debug, Default)]
pub struct ChainData {
    pub counts: HashMap<String, u32>,  // sysh name -> occurrences
    pub numbers: HashMap<String, u32>, // sysh name -> syscall number
    pub per_role: HashMap<String, u32>, // role -> occurrence total
    pub roles: HashMap<u32, String>,   // pid -> role
    pub boot_stream: Vec<String>,      // the boot pid's resolved names, in order
    pub malformed: usize,
}

pub const PHASE4_SET: &[&str] = &[
    "close", "exec", "exits", "open", "rfork", "notify", "noted", "errstr", "await", "pread",
    "pwrite",
];
pub const REQUIRED_BC: &[&str] = &["bind", "pipe", "fversion", "mount", "dup"];

/// Parse the boot-chain trace region (from the chain-launch command echo to
/// the final __GSD_ALL_DONE__ marker).
pub fn parse_chain_region(
    region: &[u8],
    defines: &HashMap<String, u32>,
) -> Result<ChainData, String> {
    let arm_re = crate::regex::Regex::new("__GSD_ARM_(boot|paqfs|srv|rc)_(\\d+)__").unwrap();
    let sweep_re = crate::regex::Regex::new("__GSD_SWEEP_(BEGIN|DONE)_(\\w+)__").unwrap();
    let frag_re = crate::regex::Regex::new("__GSD_FRAG_(\\d+)__(.*)").unwrap();
    let entry2_re = entry_re();

    let mut data = ChainData::default();

    // role map from the arm markers (byte positions irrelevant)
    let mut pos = 0usize;
    while let Some(m) = arm_re.find_at(region, pos) {
        let pid: u32 = m.group_str(2, region).unwrap().parse().unwrap_or(0);
        data.roles
            .insert(pid, m.group_str(1, region).unwrap_or("").to_string());
        pos = m.span.end;
    }

    // sweep brackets: positional spans per target binary
    let mut brackets: Vec<(String, usize, usize)> = Vec::new();
    let mut open_b: HashMap<String, usize> = HashMap::new();
    pos = 0;
    while let Some(m) = sweep_re.find_at(region, pos) {
        let kind = m.group_str(1, region).unwrap_or("");
        let name = m.group_str(2, region).unwrap_or("").to_string();
        if kind == "BEGIN" {
            open_b.insert(name, m.span.end);
        } else if kind == "DONE" && open_b.contains_key(&name) {
            let s = open_b.remove(&name).unwrap();
            brackets.push((name, s, m.span.start));
        }
        pos = m.span.end;
    }

    let mut unknown: Vec<String> = Vec::new();
    let mut pos = 0usize;
    for raw in region.split(|&b| b == b'\n') {
        let idx = pos;
        pos += raw.len() + 1;
        let Some(fm) = frag_re.find(raw) else {
            continue;
        };
        let pid: u32 = fm.group_str(1, raw).unwrap_or("0").parse().unwrap_or(0);
        let content_b = fm.group(2, raw).unwrap_or(b"");
        let content = String::from_utf8_lossy(content_b).trim().to_string();
        if content.starts_with('=') {
            continue; // return fragment
        }
        let Some(m) = entry2_re.find(content.as_bytes()) else {
            if content.contains(" = ") {
                // return fragment whose print starts with the data dump
                // (sysretfmt prints PREAD's buffer etc. before " = <ret>")
                continue;
            }
            data.malformed += 1;
            continue;
        };
        if m.group_str(1, content.as_bytes()).unwrap_or("0").parse::<u32>() != Ok(pid) {
            data.malformed += 1;
            continue; // glued/partial line — tag and fragment disagree
        }
        let name = m.group_str(3, content.as_bytes()).unwrap_or("");
        if name == "huh?" {
            unknown.push(content.clone());
            continue;
        }
        let Some((number, sysh_name)) = resolve(defines, &name.to_lowercase()) else {
            return Err(format!(
                "unknown syscall name: {} (no matching #define in sys.h)",
                name
            ));
        };
        *data.counts.entry(sysh_name.clone()).or_insert(0) += 1;
        data.numbers.insert(sysh_name.clone(), number);
        let role = match data.roles.get(&pid) {
            Some(r) => r.clone(),
            None => {
                // sweep binaries: attribute by bracket position in the region
                let mut role = None;
                for (bname, bs, be) in &brackets {
                    if *bs <= idx && idx <= *be {
                        role = Some(format!("sweep:{}", bname));
                        break;
                    }
                }
                role.unwrap_or_else(|| format!("pid {}", pid))
            }
        };
        *data.per_role.entry(role.clone()).or_insert(0) += 1;
        if role == "boot" {
            data.boot_stream.push(sysh_name);
        }
    }

    if !unknown.is_empty() {
        return Err(format!(
            "donor emitted 'huh?' — unknown syscall numbers traced: {:?}",
            &unknown[..unknown.len().min(4)]
        ));
    }
    if data.counts.is_empty() {
        return Err("no entry fragments parsed — /proc/N/syscall surprised; \
                    the fallback (dosyscall print patch) is required"
            .into());
    }

    let names: HashSet<&str> = data.counts.keys().map(|s| s.as_str()).collect();
    let missing: Vec<&str> = REQUIRED_BC
        .iter()
        .filter(|n| !names.contains(**n))
        .copied()
        .collect();
    if !missing.is_empty() {
        return Err(format!(
            "measured set lacks {} — the connectembed/nsinit flow was not measured",
            missing.join(", ")
        ));
    }
    if !["stat", "fstat", "_stat"].iter().any(|n| names.contains(n)) {
        return Err("no stat-family member in the measured set".into());
    }
    for required in ["pwrite", "exits"] {
        if !names.contains(required) {
            return Err(format!(
                "measured set lacks {} — the trace did not cover the chain",
                required
            ));
        }
    }
    Ok(data)
}

/// The opencons coverage-boundary analysis on the boot pid's stream:
/// the contiguous close×3/bind/open×3 run (boot.c:38-44). Returns
/// (opencons_at, source_additions).
pub fn opencons_analysis(boot_stream: &[String]) -> (i64, Vec<(&'static str, &'static str)>) {
    let opencons_seq = ["close", "close", "close", "bind", "open", "open", "open"];
    let boot_first: Vec<&str> = boot_stream.iter().take(24).map(|s| s.as_str()).collect();
    let mut opencons_at: i64 = -1;
    if boot_stream.len() >= opencons_seq.len() {
        for i in 0..=(boot_stream.len() - opencons_seq.len()) {
            if boot_stream[i..i + opencons_seq.len()]
                .iter()
                .map(|s| s.as_str())
                .eq(opencons_seq.iter().copied())
            {
                opencons_at = i as i64;
                break;
            }
        }
    }
    let mut additions = Vec::new();
    if opencons_at < 0 {
        let sites: HashMap<&str, &str> = HashMap::from([
            ("close", "opencons close(0/1/2) — sys/src/9k/boot/boot.c:38-40"),
            ("bind", "opencons bind(#c, /dev, MBEFORE) — boot.c:41"),
            ("open", "opencons open(/dev/cons) ×3 — boot.c:42-44"),
        ]);
        for n in ["close", "bind", "open"] {
            let have = boot_first.iter().filter(|&&x| x == n).count();
            let want = opencons_seq.iter().filter(|&&x| x == n).count();
            if have < want {
                additions.push((n, sites[n]));
            }
        }
    }
    (opencons_at, additions)
}

/// Boot-chain artifact text (byte-shape of 05-03-trace.txt).
pub fn artifact_chain(data: &ChainData, runlog_bc: &str, now_iso: &str) -> String {
    let (opencons_at, source_additions) = opencons_analysis(&data.boot_stream);
    let names: HashSet<&str> = data.counts.keys().map(|s| s.as_str()).collect();
    let mut new_names: Vec<&str> = names
        .iter()
        .filter(|n| !PHASE4_SET.contains(n))
        .copied()
        .collect();
    new_names.sort_by_key(|n| data.numbers[*n]);
    let boot_first: Vec<&str> = data.boot_stream.iter().take(24).map(|s| s.as_str()).collect();

    let mut s = String::new();
    s.push_str(&format!("# date: {}\n", now_iso));
    s.push_str(&format!("# donor pin: {} (9front branch front)\n", DONOR_SHA));
    s.push_str("# rig: build/aarch64/trace-syscalls.py --boot-chain (05-03) + build/aarch64/trace-boot.rc + build/aarch64/pidwait.c\n");
    s.push_str("# target: the REAL chain — 05-02's aarch64 boot(8) (staged /boot/ourboot)\n");
    s.push_str("#   with the embed method over /boot/ourbootfs.paq (05-02's baked bootfs.paq),\n");
    s.push_str("#   /boot/paqfs bind-overridden to OUR paqfs, the donor devroot's factotum\n");
    s.push_str("#   covered ('#c/null' bind — the glenda path, D-02), the donor's /srv/boot\n");
    s.push_str("#   removed (srvcreate collision), #e/init removed (the donor bootrc leaks\n");
    s.push_str("#   init=/arm64/init into the shared env; execinit's cputype branch is the\n");
    s.push_str("#   r9-faithful one), cputype=aarch64 + nobootprompt seeded, and the trace\n");
    s.push_str("#   namespace bound over /lib/namespace (re-mounts #s/boot at /root after\n");
    s.push_str("#   newns's RFCNAMEG wipe — the k10root mechanism — and overrides termrc).\n");
    s.push_str("#   Chain: init -t → newns → termrc (stacksmoke) → rc -c '. oursweep.rc'\n");
    s.push_str("#   (the D-09 sweep SOURCED, not typed: the donor's devcons fails /dev/cons\n");
    s.push_str("#   reads by design — Egreg; console input there is kbdfs-served, and\n");
    s.push_str("#   opencons's bind #c MBEFORE pins the kernel cons into the chain.  On r9\n");
    s.push_str("#   devcons serves reads (D-06); 05-09 drives the console for real.)\n");
    s.push_str("#   Then standalone step-traces of ourecho/ourls/ourps/ourcat/ourstacksmoke.\n");
    s.push_str("# method: startsyscall+/proc/N/syscall per-pid loops (04-01 recipe extended);\n");
    s.push_str("#   zero-slip launcher spin; born-traced children armed via pidwait -w\n");
    s.push_str("#   (fork inherits procctl — donor sysproc.c:155 — so the connectembed\n");
    s.push_str("#   child self-stops at its first syscall with the entry fragment pending)\n");
    s.push_str(&format!(
        "# serial log: {} (gitignored .build evidence)\n",
        runlog_bc
    ));
    let mut roles: Vec<(&u32, &String)> = data.roles.iter().collect();
    roles.sort();
    s.push_str(&format!(
        "# traced processes: {}\n",
        roles.iter()
            .map(|(p, r)| format!("{} pid {}", r, p))
            .collect::<Vec<_>>()
            .join("; ")
    ));
    let mut pr: Vec<(&String, &u32)> = data.per_role.iter().collect();
    pr.sort();
    s.push_str(&format!(
        "# per-role fragment counts: {}\n",
        pr.iter()
            .map(|(r, c)| format!("{}={}", r, c))
            .collect::<Vec<_>>()
            .join(", ")
    ));
    if data.malformed > 0 {
        s.push_str(&format!(
            "# malformed tagged fragments skipped: {}\n",
            data.malformed
        ));
    }
    s.push_str(&format!("# boot stream opens with: {}\n", boot_first.join(" ")));
    s.push_str("# coverage boundary: the staging binds + env writes run in the untraced\n");
    s.push_str("#   driver shell (a traced process's fork children are born traced and\n");
    s.push_str("#   self-stop — /bin/bind forks would wedge the launcher in Await); the\n");
    s.push_str("#   traced launcher itself does only spin+exec, so the boot pid's stream\n");
    s.push_str("#   may open with rc async bookkeeping but provably contains opencons's\n");
    s.push_str("#   close×3/bind/open×3 as a contiguous run (else listed as source-\n");
    s.push_str("#   verified additions below).  rc's command children (the sweep's\n");
    s.push_str("#   echo/ls/ps/cat as spawned by OUR rc) run untraced (born-traced,\n");
    s.push_str("#   resumed by the sweeper) — their names are covered by the standalone\n");
    s.push_str("#   sweep traces.\n");
    let mut rows: Vec<(&String, &u32)> = data.numbers.iter().collect();
    rows.sort_by_key(|(_, n)| **n);
    for (name, number) in rows {
        s.push_str(&format!("{} {}\n", number, name));
    }
    s.push_str("# NEW vs the Phase-4 implemented set {close exec exits open rfork notify\n");
    s.push_str("#   noted errstr await pread pwrite}:\n");
    for n in &new_names {
        s.push_str(&format!(
            "#   {} {} ({} occurrences)\n",
            data.numbers[*n], n, data.counts[*n]
        ));
    }
    s.push_str("# source-verified additions (NOT measured — slipped the arming window):\n");
    if source_additions.is_empty() {
        s.push_str("#   none — opencons's close×3/bind/open×3 appear as a contiguous run\n");
        s.push_str(&format!(
            "#   in the boot pid's stream (at offset {}; see 'boot stream opens with').\n",
            opencons_at
        ));
    } else {
        for (n, site) in &source_additions {
            s.push_str(&format!("#   {} — {}\n", n, site));
        }
    }
    s
}

// ---------------------------------------------------------------------------
// Live orchestration (drives lima + qemu per D-10)
// ---------------------------------------------------------------------------

use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::time::{Duration, Instant};

const USAGE: &str = "usage: harness trace-syscalls [--boot-chain]\n\
\n\
\x20 (default)     the 04-01 hello-path trace → 04-01-d14-trace.txt\n\
\x20 --boot-chain  the 05-03 real-chain trace (boot/init/paqfs/rc + sweep)\n\
\x20               → 05-03-trace.txt\n\
\n\
Env overrides: HARVEY, HARVEY_VM, BOOT_BUDGET, SRV9_PORT, TRACE_OUT.\n";

const SRV9_GUEST_IP: &str = "10.0.2.100";

struct Cfg {
    harvey: PathBuf,
    vm: String,
    guest: String,
    donor: PathBuf,
    dist: PathBuf,
    rootfs: PathBuf,
    sysh: PathBuf,
    artifact: PathBuf,
    artifact_bc: PathBuf,
    trace_u: PathBuf,
    trace_k: PathBuf,
    runlog: PathBuf,
    trace_bc_u: PathBuf,
    trace_bc_k: PathBuf,
    runlog_bc: PathBuf,
    boot_budget: u64,
    srv9_port: u16,
    ssh_cfg: PathBuf,
    harness_bin: PathBuf,
}

fn cfg() -> Cfg {
    let harvey = std::env::var("HARVEY")
        .map(PathBuf::from)
        .unwrap_or_else(|_| std::env::current_dir().unwrap());
    let vm = std::env::var("HARVEY_VM").unwrap_or_else(|_| "harvey".to_string());
    let dist = std::env::var("DONOR_DIST_HOST")
        .map(PathBuf::from)
        .unwrap_or_else(|_| harvey.join(".build/9front-dist"));
    let boot_budget = std::env::var("BOOT_BUDGET")
        .ok()
        .and_then(|v| v.parse().ok())
        .unwrap_or(600);
    let srv9_port = std::env::var("SRV9_PORT")
        .ok()
        .and_then(|v| v.parse().ok())
        .unwrap_or(1564);
    let ssh_cfg = PathBuf::from(std::env::var("HOME").unwrap_or_else(|_| "/root".into()))
        .join(format!(".lima/{}/ssh.config", vm));
    // D-04: $HARNESS_BIN if set, else our own binary (the subcommands are us)
    let harness_bin = match std::env::var("HARNESS_BIN") {
        Ok(v) if !v.is_empty() => PathBuf::from(v),
        _ => std::env::current_exe().unwrap_or_else(|_| PathBuf::from("harness")),
    };
    let artifact_default = harvey.join(".planning/phases/04-r9-userspace-exec-harvey-r9-abi/04-01-d14-trace.txt");
    let artifact_bc_default =
        harvey.join(".planning/phases/05-shell-boot-one-command-integration/05-03-trace.txt");
    // TRACE_OUT: additive override (gate e uses it to avoid clobbering the
    // committed evidence); applies to whichever mode runs
    let (artifact, artifact_bc) = match std::env::var("TRACE_OUT") {
        Ok(v) if !v.is_empty() => (PathBuf::from(&v), PathBuf::from(&v)),
        _ => (artifact_default, artifact_bc_default),
    };
    Cfg {
        guest: format!("lima-{}", vm),
        donor: harvey.join(".build/9front-donor"),
        rootfs: dist.join("srvroot"),
        sysh: harvey.join("sys/src/libc/9syscall/sys.h"),
        trace_u: dist.join("9qemu-trace.u"),
        trace_k: dist.join("9qemu-trace"),
        runlog: dist.join("trace-run.log"),
        trace_bc_u: dist.join("9qemu-bootchain.u"),
        trace_bc_k: dist.join("9qemu-bootchain"),
        runlog_bc: dist.join("bootchain-trace-run.log"),
        harvey,
        vm,
        dist,
        artifact,
        artifact_bc,
        boot_budget,
        srv9_port,
        ssh_cfg,
        harness_bin,
    }
}

fn die(msg: &str) -> ! {
    eprintln!("trace-syscalls: error: {}", msg);
    std::process::exit(1)
}

/// `+ argv` to stderr, then run.
fn sh(argv: &[String]) -> std::io::Result<std::process::ExitStatus> {
    eprintln!("+ {}", argv.join(" "));
    Command::new(&argv[0]).args(&argv[1..]).status()
}

fn sh_rc(argv: &[String]) -> Result<i32, String> {
    sh(argv)
        .map(|s| s.code().unwrap_or(-1))
        .map_err(|e| format!("spawn {}: {}", argv[0], e))
}

fn ssh_cmd(cfg: &Cfg, remote: &str) -> Vec<String> {
    vec![
        "ssh".into(),
        "-F".into(),
        cfg.ssh_cfg.to_string_lossy().into_owned(),
        cfg.guest.clone(),
        remote.into(),
    ]
}

fn rsync(cfg: &Cfg, src: &str, dst: &str) -> Vec<String> {
    vec![
        "rsync".into(),
        "-a".into(),
        "-e".into(),
        format!("ssh -F {}", cfg.ssh_cfg.display()),
        src.into(),
        dst.into(),
    ]
}

fn shq(s: &str) -> String {
    format!("'{}'", s.replace('\'', "'\\''"))
}

fn which(tool: &str) -> Option<PathBuf> {
    let path = std::env::var_os("PATH")?;
    for dir in std::env::split_paths(&path) {
        let p = dir.join(tool);
        if p.is_file() {
            return Some(p);
        }
    }
    None
}

fn utc_now_iso() -> String {
    let secs = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0);
    let days = secs.div_euclid(86400);
    let rem = secs.rem_euclid(86400);
    let (hh, mm, ss) = (rem / 3600, (rem % 3600) / 60, rem % 60);
    // Howard Hinnant's civil_from_days
    let z = days + 719468;
    let era = z.div_euclid(146097);
    let doe = z.rem_euclid(146097);
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = if m <= 2 { y + 1 } else { y };
    format!("{:04}-{:02}-{:02}T{:02}:{:02}:{:02}Z", y, m, d, hh, mm, ss)
}

fn find_subslice(hay: &[u8], needle: &[u8]) -> Option<usize> {
    hay.windows(needle.len()).position(|w| w == needle)
}
fn rfind_subslice(hay: &[u8], needle: &[u8]) -> Option<usize> {
    hay.windows(needle.len()).rposition(|w| w == needle)
}

// ---- phase 0: preconditions (read-only) ------------------------------------
fn preconditions(cfg: &Cfg) -> Result<(), String> {
    if !cfg.harvey.join("sys/src").is_dir() {
        return Err(format!("{} does not look like the harvey checkout", cfg.harvey.display()));
    }
    let actual = Command::new("git")
        .args(["-C", &cfg.donor.to_string_lossy(), "rev-parse", "HEAD"])
        .output()
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
        .unwrap_or_else(|_| "missing".to_string());
    if actual != DONOR_SHA {
        return Err(format!("donor pin mismatch: want {}, have {}", DONOR_SHA, actual));
    }
    if !cfg.rootfs.join("arm64/bin").is_dir() {
        return Err(format!(
            "{} incomplete — run sh build/aarch64/donor-vm-build.sh first",
            cfg.rootfs.display()
        ));
    }
    if which("limactl").is_none() {
        return Err("limactl not found — run inside the nix devshell".into());
    }
    let out = Command::new("limactl")
        .args(["list", "-q"])
        .output()
        .map_err(|e| e.to_string())?;
    if !String::from_utf8_lossy(&out.stdout)
        .split_whitespace()
        .any(|w| w == cfg.vm)
    {
        return Err(format!("lima VM '{}' does not exist", cfg.vm));
    }
    let status = Command::new("limactl")
        .args(["list", "--format", "{{.Status}}", &cfg.vm])
        .output()
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
        .unwrap_or_else(|_| "unknown".into());
    if status != "Running" {
        sh(&["limactl".into(), "start".into(), cfg.vm.clone()])
            .map_err(|e| e.to_string())?
            .success()
            .then_some(())
            .ok_or_else(|| format!("limactl start {} failed", cfg.vm))?;
    }
    if which("qemu-system-aarch64").is_none() {
        return Err("qemu-system-aarch64 not found — run inside the nix devshell".into());
    }
    // the srv9.py/gdbpoke9.py file checks become a harness-bin resolvability check
    if !cfg.harness_bin.is_file() {
        return Err(format!(
            "harness binary not resolvable at {} (set HARNESS_BIN or run via the harness)",
            cfg.harness_bin.display()
        ));
    }
    let nsrun = cfg.harvey.join("build/aarch64/nsrun.sh");
    if !nsrun.is_file() {
        return Err(format!("{} missing (plan 02-04)", nsrun.display()));
    }
    eprintln!("== preconditions ok (donor pin, lima guest, qemu, helpers)");
    Ok(())
}

// ---- phase 1: compile tracehello in the guest Harvey namespace -------------
fn compile_tracehello(cfg: &Cfg, tmpd: &Path) -> Result<PathBuf, String> {
    let src = cfg.harvey.join("build/aarch64/tracehello.c");
    eprintln!("== pushing tracehello.c to the guest checkout");
    sh_rc(&rsync(
        cfg,
        &src.to_string_lossy(),
        &format!("{}:harvey-build/build/aarch64/tracehello.c", cfg.guest),
    ))
    .and_then(|rc| (rc == 0).then_some(()).ok_or("rsync push failed".to_string()))?;
    // libc.a for aarch64 is a Phase-2 guest artifact; mk install is
    // incremental, so this is seconds when fresh and self-heals when stale.
    let cmd = "cd /sys/src/libc && objtype=aarch64 mk install && \
               cd \"$HARVEY/build/aarch64\" && \
               7c -FVw tracehello.c && 7l -o /aarch64/tracehello.7.out tracehello.7";
    let log = tmpd.join("compile.log");
    let rc = {
        let fp = std::fs::File::create(&log).map_err(|e| e.to_string())?;
        let argv = ssh_cmd(
            cfg,
            &format!(
                "cd \"harvey-build\" && nix develop -c bash build/aarch64/nsrun.sh --wrap {}",
                shq(cmd)
            ),
        );
        eprintln!("+ {}", argv.join(" "));
        Command::new(&argv[0])
            .args(&argv[1..])
            .stdout(fp.try_clone().map_err(|e| e.to_string())?)
            .stderr(fp)
            .status()
            .map_err(|e| e.to_string())?
            .code()
            .unwrap_or(-1)
    };
    if rc != 0 {
        return Err(format!("guest compile failed (rc={}); log: {}", rc, log.display()));
    }
    let out_bin = tmpd.join("tracehello.7.out");
    sh_rc(&rsync(
        cfg,
        &format!("{}:harvey-build/aarch64/tracehello.7.out", cfg.guest),
        &out_bin.to_string_lossy(),
    ))
    .and_then(|rc| (rc == 0).then_some(()).ok_or("rsync pull failed".to_string()))?;
    if std::fs::metadata(&out_bin).map(|m| m.len()).unwrap_or(0) == 0 {
        return Err("tracehello.7.out missing/empty after compile".into());
    }
    eprintln!("== tracehello.7.out compiled by vendored 7c/7l");
    Ok(out_bin)
}

// ---- phase 2: stage into the donor guest tree + rebake --------------------
const GUEST_REBUILD: &str = r#"#!/usr/bin/env bash
# trace-ns-rebuild.sh — guest side of trace-syscalls.py (self-re-entrant:
# wrap -> --ns -> --build, the run-gate.sh gate-ns-rebuild.sh shape).
# Lives in the guest's /tmp; never committed.
set -eu

DONOR="${DONOR:-$HOME/9front-donor}"
SCRATCH="${DONOR_HOSTBIN:-$HOME/9front-hostbin}"
DIST="${DONOR_DIST:-$HOME/9front-dist}"

if [ "${1:-}" = "--build" ]; then
	set -eu
	PATH="$SCRATCH:$HARVEY_LINUX_BIN:$PLAN9/bin:$PATH"
	export PATH
	objtype=arm64
	export objtype
	FORCERCFORMK=1
	export FORCERCFORMK

	cd /sys/src/9/arm64
	# force regeneration of everything derived from the CONF/bootdir:
	# mkdevc (qemu.c), mkrootall/mkrootc (the tracehello+trace.rc embed),
	# the link, and the uImage wrap.  All other objects are cached.
	rm -f qemu.c qemu.7 qemu.root.s qemu.root.7 qemu.rootc.c qemu.rootc.7 9qemu 9qemu.u
	mk 'CONF=qemu'

	[ -s 9qemu ] && [ -s 9qemu.u ] || { echo "error: relink produced no kernel" >&2; exit 1; }
	mkdir -p "$DIST"
	cp 9qemu "$DIST/9qemu-trace"
	cp 9qemu.u "$DIST/9qemu-trace.u"
	echo "== trace kernel assembled: $DIST/9qemu-trace{,.u}"
	exit 0
fi

if [ "${1:-}" = "--ns" ]; then
	set -u
	BUILD_USER="${2:?internal}"
	ENVFILE="${3:?internal}"
	. "$ENVFILE"

	[ -d "$DONOR/sys/src/9/arm64" ] || {
		echo "error: $DONOR does not look like the 9front donor checkout" >&2
		exit 1
	}

	mount --bind "$DONOR/sys" /sys
	mkdir -p /arm64
	mount --bind "$DONOR/arm64" /arm64
	mkdir -p /aarch64
	mount --bind "$DONOR/arm64" /aarch64
	mkdir -p /rc
	mount --bind "$DONOR/rc" /rc

	if [ -L /lib ]; then LIBREAL=$(readlink -f /lib); else LIBREAL=/lib; fi
	NSLIB=/tmp/tracelib.$$
	mkdir -p "$NSLIB"
	cp -a "$LIBREAL"/. "$NSLIB/"
	cp -a "$DONOR/lib"/. "$NSLIB/" 2>/dev/null || true
	chown 0:0 "$NSLIB"
	chmod 1777 "$NSLIB"
	mount --bind "$NSLIB" "$LIBREAL"

	unwind() {
		umount "$LIBREAL" 2>/dev/null || true
		rm -rf "$NSLIB"
	}
	trap unwind EXIT

	set +e
	su -c ". '$ENVFILE'; bash '$0' --build" "$BUILD_USER"
	RC=$?
	exit $RC
fi

# wrap phase: repo user, devshell env
set -eu

# CONF patch (idempotent): add tracehello + trace.rc to the guest copy's
# CONF=qemu bootdir.  mkrootall strips only `file`-identified executables,
# so the text rc script is embedded byte-identical.  Bootdir rows are
# TAB-indented (an unindented line terminates the section — a bare append
# silently drops the entry from mkrootall's list).
CONF="$DONOR/sys/src/9/arm64/qemu"
add_line() {
	# $1 = source path, $2 = boot name
	if grep -qF "	$1	$2" "$CONF"; then
		echo "== CONF already carries $2 (idempotent rerun)"
	else
		echo "== adding $2 to the guest-copy CONF=qemu bootdir"
		awk -v path="$1" -v name="$2" '
			/^bootdir$/ { inbd=1; print; next }
			inbd && /^[^ \t]/ { print "\t" path "\t" name; inbd=0; print; next }
			{ print }
			END { if (inbd) print "\t" path "\t" name }
		' "$CONF" > "$CONF.trace"
		mv "$CONF.trace" "$CONF"
	fi
}
add_line '/$objtype/bin/tracehello' 'tracehello'
add_line '/arm64/bin/trace.rc' 'trace.rc'

[ -s "$DONOR/arm64/bin/tracehello" ] || {
	echo "error: staged tracehello missing at $DONOR/arm64/bin/tracehello" >&2
	exit 1
}
[ -s "$DONOR/arm64/bin/trace.rc" ] || {
	echo "error: staged trace.rc missing at $DONOR/arm64/bin/trace.rc" >&2
	exit 1
}
chmod 755 "$DONOR/arm64/bin/tracehello"

mkdir -p "$DIST"
export DONOR SCRATCH DIST
EXPORTS=/tmp/trace-exports.$$
export > "$EXPORTS"
set +e
sudo unshare -m bash "$0" --ns "$USER" "$EXPORTS"
RC=$?
rm -f "$EXPORTS"
exit $RC
"#;

// The RESEARCH.md D-14 recipe verbatim, staged as /boot/trace.rc so the
// console only ever carries short single-line commands.
const TRACE_RC: &str = r#"# trace.rc — D-14 startsyscall loop over /proc/$1 (RESEARCH.md recipe).
# Plan 9 rc has no break builtin: the while CONDITION is the startsyscall
# write itself — when the target's EXITS lands, the write fails
# (process exited) and the loop ends.
pid = $1
echo stop > /proc/$pid/ctl || echo __GSD_TRACE_STOP_FAILED__
while (echo startsyscall > /proc/$pid/ctl)
	cat /proc/$pid/syscall
echo __GSD_TRACE_LOOP_DONE__
"#;

fn stage_and_rebake(cfg: &Cfg, tmpd: &Path, trace_bin: &Path) -> Result<(), String> {
    let rc_path = tmpd.join("trace.rc");
    std::fs::write(&rc_path, TRACE_RC).map_err(|e| e.to_string())?;
    let guest_script = tmpd.join("trace-ns-rebuild.sh");
    std::fs::write(&guest_script, GUEST_REBUILD).map_err(|e| e.to_string())?;

    eprintln!("== staging tracehello + trace.rc into the guest donor tree");
    sh_rc(&rsync(
        cfg,
        &trace_bin.to_string_lossy(),
        &format!("{}:9front-donor/arm64/bin/tracehello", cfg.guest),
    ))
    .and_then(|rc| (rc == 0).then_some(()).ok_or("rsync tracehello failed".to_string()))?;
    sh_rc(&rsync(
        cfg,
        &rc_path.to_string_lossy(),
        &format!("{}:9front-donor/arm64/bin/trace.rc", cfg.guest),
    ))
    .and_then(|rc| (rc == 0).then_some(()).ok_or("rsync trace.rc failed".to_string()))?;
    sh_rc(&rsync(
        cfg,
        &guest_script.to_string_lossy(),
        &format!("{}:/tmp/gsd-trace-ns-rebuild.sh", cfg.guest),
    ))
    .and_then(|rc| (rc == 0).then_some(()).ok_or("rsync script failed".to_string()))?;

    let log = cfg.dist.join("trace-rebuild.log");
    std::fs::create_dir_all(&cfg.dist).map_err(|e| e.to_string())?;
    eprintln!("== targeted donor kernel rebake (log: {})", log.display());
    let rc = {
        let fp = std::fs::File::create(&log).map_err(|e| e.to_string())?;
        let argv = ssh_cmd(
            cfg,
            "cd \"harvey-build-donor\" && nix develop -c bash /tmp/gsd-trace-ns-rebuild.sh",
        );
        eprintln!("+ {}", argv.join(" "));
        Command::new(&argv[0])
            .args(&argv[1..])
            .stdout(fp.try_clone().map_err(|e| e.to_string())?)
            .stderr(fp)
            .status()
            .map_err(|e| e.to_string())?
            .code()
            .unwrap_or(-1)
    };
    if rc != 0 {
        return Err(format!("guest rebake failed (rc={}); log: {}", rc, log.display()));
    }
    sh_rc(&rsync(
        cfg,
        &format!("{}:9front-dist/9qemu-trace", cfg.guest),
        &cfg.trace_k.to_string_lossy(),
    ))
    .and_then(|rc| (rc == 0).then_some(()).ok_or("rsync kernel failed".to_string()))?;
    sh_rc(&rsync(
        cfg,
        &format!("{}:9front-dist/9qemu-trace.u", cfg.guest),
        &cfg.trace_u.to_string_lossy(),
    ))
    .and_then(|rc| (rc == 0).then_some(()).ok_or("rsync kernel.u failed".to_string()))?;
    if std::fs::metadata(&cfg.trace_u).map(|m| m.len()).unwrap_or(0) == 0 {
        return Err("9qemu-trace.u missing/empty after pull".into());
    }
    eprintln!("== trace kernel: {}", cfg.trace_u.display());
    Ok(())
}

// ---- phase 3/4: boot + drive + trace ---------------------------------------

/// Kill-on-drop guard for the spawned child processes.
struct Procs(Vec<std::process::Child>);
impl Procs {
    fn push(&mut self, c: std::process::Child) {
        self.0.push(c);
    }
}
impl Drop for Procs {
    fn drop(&mut self) {
        for p in &mut self.0 {
            let _ = p.kill();
        }
    }
}

fn boot_and_trace(cfg: &Cfg, tmpd: &Path) -> Result<Vec<u8>, String> {
    let qemu = which("qemu-system-aarch64")
        .map(|p| p.to_string_lossy().into_owned())
        .unwrap_or_else(|| "qemu-system-aarch64".into());
    let serial = tmpd.join("serial.sock");
    let qmp = tmpd.join("qmp.sock");
    let gdb = tmpd.join("gdb.sock");
    let mut procs = Procs(Vec::new());
    let mut err = std::io::stderr();

    // serve the root fs (9P2000, read-only) — same srvroot the proven
    // run-gate boot used; tracehello comes from devroot, not from here.
    let srv9_log = std::fs::File::create(tmpd.join("srv9.log")).map_err(|e| e.to_string())?;
    let srv9 = Command::new(&cfg.harness_bin)
        .arg("srv9")
        .args([
            "serve",
            "--root",
            &cfg.rootfs.to_string_lossy(),
            "--host",
            "127.0.0.1",
            "--port",
            &cfg.srv9_port.to_string(),
        ])
        .stdout(srv9_log.try_clone().map_err(|e| e.to_string())?)
        .stderr(srv9_log)
        .spawn()
        .map_err(|e| format!("spawn harness srv9: {}", e))?;
    let mut srv9 = Some(srv9);
    let mut listening = false;
    for _ in 0..60 {
        if std::net::TcpStream::connect(("127.0.0.1", cfg.srv9_port)).is_ok() {
            listening = true;
            break;
        }
        if let Some(s) = srv9.as_mut() {
            if let Ok(Some(_)) = s.try_wait() {
                procs.push(srv9.take().unwrap());
                return Err("srv9 exited during startup".into());
            }
        }
        std::thread::sleep(Duration::from_secs(1));
    }
    if !listening {
        return Err(format!("srv9 did not start listening on 127.0.0.1:{}", cfg.srv9_port));
    }

    let result = (|| -> Result<Vec<u8>, String> {
        // dump the DTB with -append baked in, then pre-place it at
        // 0x40000000 via the generic loader (run-gate drift accommodation 1)
        let append = format!("bootargs=tcp fs={} user=glenda console=0", SRV9_GUEST_IP);
        let dtb = tmpd.join("virt.dtb");
        let mut dumper = Command::new(&qemu)
            .args([
                "-M", "virt,gic-version=3,highmem-ecam=off",
                "-cpu", "cortex-a72", "-m", "1G", "-kernel",
            ])
            .arg(&cfg.trace_u)
            .args(["-append", &append])
            .arg("-machine")
            .arg(format!("dumpdtb={}", dtb.display()))
            .args(["-display", "none", "-S"])
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn()
            .map_err(|e| format!("spawn qemu dumpdtb: {}", e))?;
        std::thread::sleep(Duration::from_secs(2));
        let _ = dumper.kill();
        let _ = dumper.wait();
        if std::fs::metadata(&dtb).map(|m| m.len()).unwrap_or(0) == 0 {
            return Err("qemu dumpdtb produced no DTB".into());
        }

        let qerr = std::fs::File::create(tmpd.join("qemu.err")).map_err(|e| e.to_string())?;
        let qp = Command::new(&qemu)
            .args([
                "-M", "virt,gic-version=3,highmem-ecam=off", "-cpu", "cortex-a72",
                "-accel", "tcg", "-smp", "1", "-m", "1G", "-kernel",
            ])
            .arg(&cfg.trace_u)
            .args(["-append", &append])
            .args(["-device", &format!("loader,file={},addr=0x40000000", dtb.display())])
            .args([
                "-netdev",
                &format!(
                    "user,id=n0,guestfwd=tcp:{}:564-tcp:127.0.0.1:{}",
                    SRV9_GUEST_IP, cfg.srv9_port
                ),
            ])
            .args(["-device", "virtio-net-pci-non-transitional,netdev=n0"])
            .args([
                "-chardev",
                &format!("socket,id=ser0,path={},server=on,wait=off", serial.display()),
            ])
            .args(["-serial", "chardev:ser0"])
            .args(["-qmp", &format!("unix:{},server=on,wait=off", qmp.display())])
            .args(["-gdb", &format!("unix:{},server=on,wait=off", gdb.display())])
            .args(["-S", "-display", "none"])
            .stdout(qerr.try_clone().map_err(|e| e.to_string())?)
            .stderr(qerr)
            .spawn()
            .map_err(|e| format!("spawn qemu: {}", e))?;
        procs.push(qp);
        std::thread::sleep(Duration::from_secs(2));
        if let Some(Some(_)) = procs.0.last_mut().map(|p| p.try_wait().ok().flatten()) {
            return Err(format!("qemu exited during launch (see {})", tmpd.join("qemu.err").display()));
        }

        // wake the GIC redistributor (run-gate drift accommodation 2)
        let poke_log = std::fs::File::create(tmpd.join("gdbpoke.log")).map_err(|e| e.to_string())?;
        let poke = Command::new(&cfg.harness_bin)
            .arg("gdbpoke9")
            .args([
                "--sock",
                &gdb.to_string_lossy(),
                "--watch-file",
                &cfg.runlog.to_string_lossy(),
                "--watch-str",
                "bootargs is",
                "--deadline",
                &cfg.boot_budget.to_string(),
            ])
            .stdout(poke_log.try_clone().map_err(|e| e.to_string())?)
            .stderr(poke_log)
            .spawn()
            .map_err(|e| format!("spawn harness gdbpoke9: {}", e))?;
        procs.push(poke);

        // capture BEFORE the guest runs, then resume
        let log = crate::console::Log::new(&cfg.runlog, 256 * 1024 * 1024, 128 * 1024 * 1024)
            .map_err(|e| format!("open runlog: {}", e))?;
        let deadline = Instant::now() + Duration::from_secs(cfg.boot_budget);
        let mut sopt = None;
        while Instant::now() < deadline {
            match std::os::unix::net::UnixStream::connect(&serial) {
                Ok(s) => {
                    sopt = Some(s);
                    break;
                }
                Err(_) => std::thread::sleep(Duration::from_millis(500)),
            }
        }
        let Some(s) = sopt else {
            crate::console::fail(&log, "trace-syscalls", "serial socket never appeared", &mut err);
            return Err("serial socket never appeared".into());
        };
        crate::console::spawn_reader(s.try_clone().map_err(|e| e.to_string())?, log.clone());
        crate::console::qmp_cont(&qmp).map_err(|e| format!("qmp cont failed: {}", e))?;
        eprintln!("== capture attached, guest resumed (budget {}s)", cfg.boot_budget);

        // the shared boot drive (trace-syscalls.py's ShellOk prompt-proof variant)
        if crate::console::drive_boot(
            &s,
            &log,
            deadline,
            cfg.boot_budget,
            "trace-syscalls",
            crate::console::PromptProbe::ShellOk,
            &mut err,
        )
        .is_err()
        {
            return Err("boot drive failed".into());
        }
        eprintln!("== shell live and idle; starting the trace");

        // launch the trace target backgrounded and capture its pid. The
        // target's leading pure-compute spin makes no syscalls, so nothing
        // can fire before the tracer arms.
        let panic_re = crate::console::panic_re();
        let pid_re = crate::regex::Regex::new("__GSD_PID__(\\d+)").unwrap();
        let base = log.len();
        crate::console::paced_send(&s, b"/boot/tracehello &; echo __GSD_PID__$apid\r");
        let pdeadline = Instant::now() + Duration::from_secs(60);
        let (pid, pid_marker_end): (u32, usize) = loop {
            if Instant::now() >= pdeadline {
                crate::console::fail(&log, "trace-syscalls", "no pid probe output", &mut err);
                return Err("no pid probe output".into());
            }
            if panic_re.is_match(&log.tail(8192)) {
                crate::console::fail(&log, "trace-syscalls", "kernel fault at trace launch", &mut err);
                return Err("kernel fault at trace launch".into());
            }
            if let Some(m) = log.find_from(&pid_re, base) {
                let buf = log.snapshot();
                let p: u32 = m.group_str(1, &buf).and_then(|g| g.parse().ok()).unwrap_or(0);
                break (p, m.span.end);
            }
            std::thread::sleep(Duration::from_millis(500));
        };
        eprintln!("== tracehello launched: pid {}", pid);

        // the pid marker is NOT a prompt — rc may still be printing 'term% '
        // when the trace command starts; an interleaved echo ("rterm% c
        // /boot/trace.rc 196") breaks the parse's contiguous start-marker
        // search. Wait for the fresh prompt to appear (its print is a single
        // flushed write — presence means rc is idle), then send immediately:
        // tracehello's ~15s pure-compute spin (calibrated, see
        // tracehello.c) leaves a wide quiet window before its first print.
        // (The .py raced here and won by TCG timing luck; the gate hit it on
        // the first Rust run.)
        let prompt_substr = crate::regex::Regex::new("term% ").unwrap();
        let wdeadline = Instant::now() + Duration::from_secs(60);
        loop {
            if Instant::now() >= wdeadline {
                crate::console::fail(
                    &log,
                    "trace-syscalls",
                    "no prompt after the pid probe",
                    &mut err,
                );
                return Err("no prompt after the pid probe".into());
            }
            if panic_re.is_match(&log.tail(8192)) {
                crate::console::fail(&log, "trace-syscalls", "kernel fault at trace launch", &mut err);
                return Err("kernel fault at trace launch".into());
            }
            // search after the pid marker (its span end — the buffer is
            // append-only under the 256MiB window, so the span stays valid)
            if log.find_from(&prompt_substr, pid_marker_end).is_some() {
                break;
            }
            std::thread::sleep(Duration::from_millis(100));
        }

        // run the trace loop (RESEARCH recipe, staged as /boot/trace.rc)
        let done_re = crate::regex::Regex::new("^__GSD_TRACE_LOOP_DONE__\r?$").unwrap();
        let base = log.len();
        crate::console::paced_send(&s, format!("rc /boot/trace.rc {}\r", pid).as_bytes());
        let tdeadline = Instant::now() + Duration::from_secs(360);
        loop {
            if Instant::now() >= tdeadline {
                crate::console::fail(
                    &log,
                    "trace-syscalls",
                    "trace loop never completed (Eprocdied break not seen)",
                    &mut err,
                );
                return Err("trace loop never completed".into());
            }
            if panic_re.is_match(&log.tail(8192)) {
                crate::console::fail(&log, "trace-syscalls", "kernel fault during trace", &mut err);
                return Err("kernel fault during trace".into());
            }
            if log.search_from(&done_re, base) {
                break;
            }
            std::thread::sleep(Duration::from_secs(1));
        }
        eprintln!("== trace loop complete");
        std::fs::read(&cfg.runlog).map_err(|e| format!("read runlog: {}", e))
    })();
    if let Some(s) = srv9.take() {
        procs.push(s);
    }
    result
}

// ---- phase 5: parse + artifact ----------------------------------------------
fn parse_and_write(cfg: &Cfg, capture: &[u8]) -> Result<(), String> {
    // fragments live between the trace.rc command echo and the done marker
    let start = find_subslice(capture, b"rc /boot/trace.rc");
    let end = rfind_subslice(capture, b"__GSD_TRACE_LOOP_DONE__");
    let (start, end) = match (start, end) {
        (Some(s), Some(e)) if e > s => (s, e),
        _ => {
            return Err(format!(
                "trace region not bracketed in the serial log (see {})",
                cfg.runlog.display()
            ))
        }
    };
    let region = String::from_utf8_lossy(&capture[start..end]).into_owned();
    let defines_text = std::fs::read_to_string(&cfg.sysh)
        .map_err(|e| format!("read {}: {}", cfg.sysh.display(), e))?;
    let defines = load_sysh(&defines_text);
    let ordered = parse_hello_region(&region, &defines)?;
    let text = artifact_hello(&ordered, &cfg.runlog.to_string_lossy(), &utc_now_iso());
    std::fs::write(&cfg.artifact, &text)
        .map_err(|e| format!("write {}: {}", cfg.artifact.display(), e))?;
    eprintln!(
        "== artifact written: {} ({} syscalls)",
        cfg.artifact.display(),
        ordered.len()
    );
    for (number, name) in &ordered {
        eprintln!("   {} {}", number, name);
    }
    Ok(())
}

// ======================================================================
// 05-03 --boot-chain: trace the REAL boot chain on the 9front donor kernel.
// ======================================================================

// host path in this repo → guest donor arm64/bin bootdir name
const STAGE_BC: &[(&str, &str)] = &[
    ("build/aarch64/out/boot", "ourboot"),
    ("build/aarch64/out/init", "ourinit"),
    ("build/aarch64/out/paqfs", "ourpaqfs"),
    ("build/aarch64/out/stacksmoke", "ourstacksmoke"),
    ("aarch64/bin/rc", "ourrc"),
    ("aarch64/bin/echo", "ourecho"),
    ("aarch64/bin/ls", "ourls"),
    ("aarch64/bin/ps", "ourps"),
    ("aarch64/bin/cat", "ourcat"),
    ("build/aarch64/bootfs.paq", "ourbootfs.paq"),
    // trace-rig guest assets (data — ride the bootdir through mkrootall)
    ("build/aarch64/trace-namespace", "ournamespace"),
    ("build/aarch64/trace-termrc", "ourtermrc"),
    ("build/aarch64/trace-sweep.rc", "oursweep.rc"),
];

const BC_BINARIES: &[&str] = &[
    "ourboot", "ourinit", "ourpaqfs", "ourstacksmoke", "ourrc", "ourecho", "ourls", "ourps",
    "ourcat",
];

fn preconditions_bc(cfg: &Cfg) -> Result<(), String> {
    preconditions(cfg)?;
    for (rel, name) in STAGE_BC {
        let p = cfg.harvey.join(rel);
        if std::fs::metadata(&p).map(|m| m.len()).unwrap_or(0) == 0 {
            return Err(format!(
                "{} missing/empty — run subset-build.sh + mkimage.sh (05-02) first",
                p.display()
            ));
        }
        if BC_BINARIES.contains(name) {
            let magic = std::fs::read(&p).map_err(|e| e.to_string())?;
            if magic.len() < 4 || magic[..4] != [0x00, 0x00, 0x8c, 0x47] {
                return Err(format!(
                    "{} lacks R_MAGIC 00008c47 — not a 7l aarch64 binary",
                    p.display()
                ));
            }
        }
    }
    for helper in ["trace-boot.rc", "pidwait.c"] {
        let p = cfg.harvey.join("build/aarch64").join(helper);
        if !p.is_file() {
            return Err(format!("build/aarch64/{} missing (05-03)", helper));
        }
    }
    eprintln!("== boot-chain preconditions ok (05-02 binaries + image present)");
    Ok(())
}

fn compile_pidwait(cfg: &Cfg, tmpd: &Path) -> Result<PathBuf, String> {
    let src = cfg.harvey.join("build/aarch64/pidwait.c");
    eprintln!("== pushing pidwait.c to the guest checkout");
    sh_rc(&rsync(
        cfg,
        &src.to_string_lossy(),
        &format!("{}:harvey-build/build/aarch64/pidwait.c", cfg.guest),
    ))
    .and_then(|rc| (rc == 0).then_some(()).ok_or("rsync push failed".to_string()))?;
    let cmd = "cd /sys/src/libc && objtype=aarch64 mk install && \
               cd \"$HARVEY/build/aarch64\" && \
               7c -FVw pidwait.c && 7l -o /aarch64/pidwait.7.out pidwait.7";
    let log = tmpd.join("compile-pidwait.log");
    let rc = {
        let fp = std::fs::File::create(&log).map_err(|e| e.to_string())?;
        let argv = ssh_cmd(
            cfg,
            &format!(
                "cd \"harvey-build\" && nix develop -c bash build/aarch64/nsrun.sh --wrap {}",
                shq(cmd)
            ),
        );
        eprintln!("+ {}", argv.join(" "));
        Command::new(&argv[0])
            .args(&argv[1..])
            .stdout(fp.try_clone().map_err(|e| e.to_string())?)
            .stderr(fp)
            .status()
            .map_err(|e| e.to_string())?
            .code()
            .unwrap_or(-1)
    };
    if rc != 0 {
        return Err(format!("guest pidwait compile failed (rc={}); log: {}", rc, log.display()));
    }
    let out_bin = tmpd.join("pidwait.7.out");
    sh_rc(&rsync(
        cfg,
        &format!("{}:harvey-build/aarch64/pidwait.7.out", cfg.guest),
        &out_bin.to_string_lossy(),
    ))
    .and_then(|rc| (rc == 0).then_some(()).ok_or("rsync pull failed".to_string()))?;
    if std::fs::metadata(&out_bin).map(|m| m.len()).unwrap_or(0) == 0 {
        return Err("pidwait.7.out missing/empty after compile".into());
    }
    eprintln!("== pidwait.7.out compiled by vendored 7c/7l");
    Ok(out_bin)
}

// The boot-chain guest rebuild: same self-re-entrant shape as GUEST_REBUILD
// (wrap -> --ns -> --build) with the 05-03 staging set.
const GUEST_REBUILD_BC: &str = r#"#!/usr/bin/env bash
# trace-bootchain-ns-rebuild.sh — guest side of trace-syscalls.py
# --boot-chain (the trace-ns-rebuild.sh shape).  Lives in the guest's
# /tmp; never committed.
set -eu

DONOR="${DONOR:-$HOME/9front-donor}"
SCRATCH="${DONOR_HOSTBIN:-$HOME/9front-hostbin}"
DIST="${DONOR_DIST:-$HOME/9front-dist}"

if [ "${1:-}" = "--build" ]; then
	set -eu
	PATH="$SCRATCH:$HARVEY_LINUX_BIN:$PLAN9/bin:$PATH"
	export PATH
	objtype=arm64
	export objtype
	FORCERCFORMK=1
	export FORCERCFORMK

	cd /sys/src/9/arm64
	# force regeneration of everything derived from the CONF/bootdir
	rm -f qemu.c qemu.7 qemu.root.s qemu.root.7 qemu.rootc.c qemu.rootc.7 9qemu 9qemu.u
	mk 'CONF=qemu'

	[ -s 9qemu ] && [ -s 9qemu.u ] || { echo "error: relink produced no kernel" >&2; exit 1; }
	mkdir -p "$DIST"
	cp 9qemu "$DIST/9qemu-bootchain"
	cp 9qemu.u "$DIST/9qemu-bootchain.u"
	echo "== boot-chain trace kernel assembled: $DIST/9qemu-bootchain{,.u}"
	exit 0
fi

if [ "${1:-}" = "--ns" ]; then
	set -u
	BUILD_USER="${2:?internal}"
	ENVFILE="${3:?internal}"
	. "$ENVFILE"

	[ -d "$DONOR/sys/src/9/arm64" ] || {
		echo "error: $DONOR does not look like the 9front donor checkout" >&2
		exit 1
	}

	mount --bind "$DONOR/sys" /sys
	mkdir -p /arm64
	mount --bind "$DONOR/arm64" /arm64
	mkdir -p /aarch64
	mount --bind "$DONOR/arm64" /aarch64
	mkdir -p /rc
	mount --bind "$DONOR/rc" /rc

	if [ -L /lib ]; then LIBREAL=$(readlink -f /lib); else LIBREAL=/lib; fi
	NSLIB=/tmp/tracebclib.$$
	mkdir -p "$NSLIB"
	cp -a "$LIBREAL"/. "$NSLIB/"
	cp -a "$DONOR/lib"/. "$NSLIB/" 2>/dev/null || true
	chown 0:0 "$NSLIB"
	chmod 1777 "$NSLIB"
	mount --bind "$NSLIB" "$LIBREAL"

	unwind() {
		umount "$LIBREAL" 2>/dev/null || true
		rm -rf "$NSLIB"
	}
	trap unwind EXIT

	set +e
	su -c ". '$ENVFILE'; bash '$0' --build" "$BUILD_USER"
	RC=$?
	exit $RC
fi

# wrap phase: repo user, devshell env
set -eu

# CONF patch (idempotent): bootdir rows are TAB-indented (an unindented
# line terminates the section).  The .paq and .rc ride as data — the
# mkrootall strip covers only file-identified executables.
#
# The donor kernel panics "too many root files" past Nbootfiles=32
# (devroot.c) and the guest-scratch CONF has accumulated bootdir lines
# from every gate since 02-05 — reset the section to the four stock
# rows + ours before adding (the dropped gates re-add their own lines
# idempotently on their own reruns; nothing here is committed anywhere).
CONF="$DONOR/sys/src/9/arm64/qemu"
awk '
	/^bootdir$/ { inbd=1; print; next }
	inbd && /^[^ \t]/ {
		print "\tboot"
		print "\t/$objtype/bin/paqfs"
		print "\t/$objtype/bin/auth/factotum"
		print "\t$CONF.bootfs.paq\tbootfs.paq"
		inbd=0; print; next
	}
	inbd && /^\t/ { next }
	{ print }
	END {
		if (inbd) {
			print "\tboot"
			print "\t/$objtype/bin/paqfs"
			print "\t/$objtype/bin/auth/factotum"
			print "\t$CONF.bootfs.paq\tbootfs.paq"
		}
	}
' "$CONF" > "$CONF.prune" && mv "$CONF.prune" "$CONF"
echo "== CONF bootdir pruned to stock + 05-03 staging set"
add_line() {
	if grep -qF "	$1	$2" "$CONF"; then
		echo "== CONF already carries $2 (idempotent rerun)"
	else
		echo "== adding $2 to the guest-copy CONF=qemu bootdir"
		awk -v path="$1" -v name="$2" '
			/^bootdir$/ { inbd=1; print; next }
			inbd && /^[^ \t]/ { print "\t" path "\t" name; inbd=0; print; next }
			{ print }
			END { if (inbd) print "\t" path "\t" name }
		' "$CONF" > "$CONF.tracebc"
		mv "$CONF.tracebc" "$CONF"
	fi
}
for n in ourboot ourinit ourpaqfs ourstacksmoke ourrc ourecho ourls ourps ourcat pidwait; do
	add_line "/\$objtype/bin/$n" "$n"
done
add_line '/$objtype/bin/ourbootfs.paq' 'ourbootfs.paq'
add_line '/$objtype/bin/trace-boot.rc' 'trace-boot.rc'
add_line '/$objtype/bin/ournamespace' 'ournamespace'
add_line '/$objtype/bin/ourtermrc' 'ourtermrc'
add_line '/$objtype/bin/oursweep.rc' 'oursweep.rc'

for n in ourboot ourinit ourpaqfs ourstacksmoke ourrc ourecho ourls ourps ourcat pidwait ourbootfs.paq trace-boot.rc ournamespace ourtermrc oursweep.rc; do
	[ -s "$DONOR/arm64/bin/$n" ] || {
		echo "error: staged $n missing at $DONOR/arm64/bin/$n" >&2
		exit 1
	}
done
chmod 755 "$DONOR/arm64/bin"/our* "$DONOR/arm64/bin/pidwait"

mkdir -p "$DIST"
export DONOR SCRATCH DIST
EXPORTS=/tmp/tracebc-exports.$$
export > "$EXPORTS"
set +e
sudo unshare -m bash "$0" --ns "$USER" "$EXPORTS"
RC=$?
rm -f "$EXPORTS"
exit $RC
"#;

fn stage_and_rebake_bc(cfg: &Cfg, tmpd: &Path, pidwait_bin: &Path) -> Result<(), String> {
    let guest_script = tmpd.join("trace-bootchain-ns-rebuild.sh");
    std::fs::write(&guest_script, GUEST_REBUILD_BC).map_err(|e| e.to_string())?;

    eprintln!("== staging the real chain + trace driver into the guest donor tree");
    for (rel, name) in STAGE_BC {
        sh_rc(&rsync(
            cfg,
            &cfg.harvey.join(rel).to_string_lossy(),
            &format!("{}:9front-donor/arm64/bin/{}", cfg.guest, name),
        ))
        .and_then(|rc| (rc == 0).then_some(()).ok_or_else(|| format!("rsync {} failed", rel)))?;
    }
    sh_rc(&rsync(
        cfg,
        &pidwait_bin.to_string_lossy(),
        &format!("{}:9front-donor/arm64/bin/pidwait", cfg.guest),
    ))
    .and_then(|rc| (rc == 0).then_some(()).ok_or("rsync pidwait failed".to_string()))?;
    sh_rc(&rsync(
        cfg,
        &cfg.harvey.join("build/aarch64/trace-boot.rc").to_string_lossy(),
        &format!("{}:9front-donor/arm64/bin/trace-boot.rc", cfg.guest),
    ))
    .and_then(|rc| (rc == 0).then_some(()).ok_or("rsync trace-boot.rc failed".to_string()))?;
    sh_rc(&rsync(
        cfg,
        &guest_script.to_string_lossy(),
        &format!("{}:/tmp/gsd-tracebc-ns-rebuild.sh", cfg.guest),
    ))
    .and_then(|rc| (rc == 0).then_some(()).ok_or("rsync script failed".to_string()))?;

    let log = cfg.dist.join("bootchain-rebuild.log");
    std::fs::create_dir_all(&cfg.dist).map_err(|e| e.to_string())?;
    eprintln!("== targeted donor kernel rebake (log: {})", log.display());
    let rc = {
        let fp = std::fs::File::create(&log).map_err(|e| e.to_string())?;
        let argv = ssh_cmd(
            cfg,
            "cd \"harvey-build-donor\" && nix develop -c bash /tmp/gsd-tracebc-ns-rebuild.sh",
        );
        eprintln!("+ {}", argv.join(" "));
        Command::new(&argv[0])
            .args(&argv[1..])
            .stdout(fp.try_clone().map_err(|e| e.to_string())?)
            .stderr(fp)
            .status()
            .map_err(|e| e.to_string())?
            .code()
            .unwrap_or(-1)
    };
    if rc != 0 {
        return Err(format!("guest rebake failed (rc={}); log: {}", rc, log.display()));
    }
    sh_rc(&rsync(
        cfg,
        &format!("{}:9front-dist/9qemu-bootchain", cfg.guest),
        &cfg.trace_bc_k.to_string_lossy(),
    ))
    .and_then(|rc| (rc == 0).then_some(()).ok_or("rsync kernel failed".to_string()))?;
    sh_rc(&rsync(
        cfg,
        &format!("{}:9front-dist/9qemu-bootchain.u", cfg.guest),
        &cfg.trace_bc_u.to_string_lossy(),
    ))
    .and_then(|rc| (rc == 0).then_some(()).ok_or("rsync kernel.u failed".to_string()))?;
    if std::fs::metadata(&cfg.trace_bc_u).map(|m| m.len()).unwrap_or(0) == 0 {
        return Err("9qemu-bootchain.u missing/empty after pull".into());
    }
    eprintln!("== boot-chain trace kernel: {}", cfg.trace_bc_u.display());
    Ok(())
}

// ---- boot-chain phase 3/4: boot + drive + trace ----------------------------

/// paced wait for rx in the log region after base; panic fast-fail.
fn expect_from(
    log: &crate::console::Log,
    rx: &crate::regex::Regex,
    base: usize,
    deadline_s: u64,
    what: &str,
    err: &mut dyn Write,
) -> bool {
    let panic_re = crate::console::panic_re();
    let deadline = Instant::now() + Duration::from_secs(deadline_s);
    while Instant::now() < deadline {
        if panic_re.is_match(&log.tail(8192)) {
            crate::console::fail(log, "trace-syscalls", &format!("kernel fault while waiting for {}", what), err);
            return false;
        }
        if log.search_from(rx, base) {
            return true;
        }
        std::thread::sleep(Duration::from_secs(1));
    }
    crate::console::fail(log, "trace-syscalls", &format!("no {} within {}s", what, deadline_s), err);
    false
}

fn boot_and_trace_chain(cfg: &Cfg, tmpd: &Path) -> Result<Vec<u8>, String> {
    let qemu = which("qemu-system-aarch64")
        .map(|p| p.to_string_lossy().into_owned())
        .unwrap_or_else(|| "qemu-system-aarch64".into());
    let serial = tmpd.join("serial.sock");
    let qmp = tmpd.join("qmp.sock");
    let gdb = tmpd.join("gdb.sock");
    let mut procs = Procs(Vec::new());
    let mut err = std::io::stderr();

    // serve the root fs (9P2000, read-only) — the donor's own boot mounts
    // it; our chain's pieces come from devroot (the bootdir embed).
    let srv9_log = std::fs::File::create(tmpd.join("srv9.log")).map_err(|e| e.to_string())?;
    let srv9 = Command::new(&cfg.harness_bin)
        .arg("srv9")
        .args([
            "serve",
            "--root",
            &cfg.rootfs.to_string_lossy(),
            "--host",
            "127.0.0.1",
            "--port",
            &cfg.srv9_port.to_string(),
        ])
        .stdout(srv9_log.try_clone().map_err(|e| e.to_string())?)
        .stderr(srv9_log)
        .spawn()
        .map_err(|e| format!("spawn harness srv9: {}", e))?;
    let mut srv9 = Some(srv9);
    let mut listening = false;
    for _ in 0..60 {
        if std::net::TcpStream::connect(("127.0.0.1", cfg.srv9_port)).is_ok() {
            listening = true;
            break;
        }
        if let Some(s) = srv9.as_mut() {
            if let Ok(Some(_)) = s.try_wait() {
                procs.push(srv9.take().unwrap());
                return Err("srv9 exited during startup".into());
            }
        }
        std::thread::sleep(Duration::from_secs(1));
    }
    if !listening {
        return Err(format!("srv9 did not start listening on 127.0.0.1:{}", cfg.srv9_port));
    }

    let result = (|| -> Result<Vec<u8>, String> {
        let append = format!("bootargs=tcp fs={} user=glenda console=0", SRV9_GUEST_IP);
        let dtb = tmpd.join("virt.dtb");
        let mut dumper = Command::new(&qemu)
            .args([
                "-M", "virt,gic-version=3,highmem-ecam=off",
                "-cpu", "cortex-a72", "-m", "1G", "-kernel",
            ])
            .arg(&cfg.trace_bc_u)
            .args(["-append", &append])
            .arg("-machine")
            .arg(format!("dumpdtb={}", dtb.display()))
            .args(["-display", "none", "-S"])
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn()
            .map_err(|e| format!("spawn qemu dumpdtb: {}", e))?;
        std::thread::sleep(Duration::from_secs(2));
        let _ = dumper.kill();
        let _ = dumper.wait();
        if std::fs::metadata(&dtb).map(|m| m.len()).unwrap_or(0) == 0 {
            return Err("qemu dumpdtb produced no DTB".into());
        }

        let qerr = std::fs::File::create(tmpd.join("qemu.err")).map_err(|e| e.to_string())?;
        let qp = Command::new(&qemu)
            .args([
                "-M", "virt,gic-version=3,highmem-ecam=off", "-cpu", "cortex-a72",
                "-accel", "tcg", "-smp", "1", "-m", "1G", "-kernel",
            ])
            .arg(&cfg.trace_bc_u)
            .args(["-append", &append])
            .args(["-device", &format!("loader,file={},addr=0x40000000", dtb.display())])
            .args([
                "-netdev",
                &format!(
                    "user,id=n0,guestfwd=tcp:{}:564-tcp:127.0.0.1:{}",
                    SRV9_GUEST_IP, cfg.srv9_port
                ),
            ])
            .args(["-device", "virtio-net-pci-non-transitional,netdev=n0"])
            .args([
                "-chardev",
                &format!("socket,id=ser0,path={},server=on,wait=off", serial.display()),
            ])
            .args(["-serial", "chardev:ser0"])
            .args(["-qmp", &format!("unix:{},server=on,wait=off", qmp.display())])
            .args(["-gdb", &format!("unix:{},server=on,wait=off", gdb.display())])
            .args(["-S", "-display", "none"])
            .stdout(qerr.try_clone().map_err(|e| e.to_string())?)
            .stderr(qerr)
            .spawn()
            .map_err(|e| format!("spawn qemu: {}", e))?;
        procs.push(qp);
        std::thread::sleep(Duration::from_secs(2));
        if let Some(Some(_)) = procs.0.last_mut().map(|p| p.try_wait().ok().flatten()) {
            return Err(format!("qemu exited during launch (see {})", tmpd.join("qemu.err").display()));
        }

        let poke_log = std::fs::File::create(tmpd.join("gdbpoke.log")).map_err(|e| e.to_string())?;
        let poke = Command::new(&cfg.harness_bin)
            .arg("gdbpoke9")
            .args([
                "--sock",
                &gdb.to_string_lossy(),
                "--watch-file",
                &cfg.runlog_bc.to_string_lossy(),
                "--watch-str",
                "bootargs is",
                "--deadline",
                &cfg.boot_budget.to_string(),
            ])
            .stdout(poke_log.try_clone().map_err(|e| e.to_string())?)
            .stderr(poke_log)
            .spawn()
            .map_err(|e| format!("spawn harness gdbpoke9: {}", e))?;
        procs.push(poke);

        let log = crate::console::Log::new(&cfg.runlog_bc, 256 * 1024 * 1024, 128 * 1024 * 1024)
            .map_err(|e| format!("open runlog: {}", e))?;
        let deadline = Instant::now() + Duration::from_secs(cfg.boot_budget);
        let mut sopt = None;
        while Instant::now() < deadline {
            match std::os::unix::net::UnixStream::connect(&serial) {
                Ok(s) => {
                    sopt = Some(s);
                    break;
                }
                Err(_) => std::thread::sleep(Duration::from_millis(500)),
            }
        }
        let Some(s) = sopt else {
            crate::console::fail(&log, "trace-syscalls", "serial socket never appeared", &mut err);
            return Err("serial socket never appeared".into());
        };
        crate::console::spawn_reader(s.try_clone().map_err(|e| e.to_string())?, log.clone());
        crate::console::qmp_cont(&qmp).map_err(|e| format!("qmp cont failed: {}", e))?;
        eprintln!("== capture attached, guest resumed (budget {}s)", cfg.boot_budget);

        // donor boot to the rc shell (the ShellOk prompt-proof variant)
        if crate::console::drive_boot(
            &s,
            &log,
            deadline,
            cfg.boot_budget,
            "trace-syscalls",
            crate::console::PromptProbe::ShellOk,
            &mut err,
        )
        .is_err()
        {
            return Err("boot drive failed".into());
        }
        eprintln!("== shell live and idle; launching the chain trace");

        // ---- chain phase --------------------------------------------------
        let panic_re = crate::console::panic_re();
        let armed_re = crate::regex::Regex::new("^__GSD_CHAIN_ARMED__\r?$").unwrap();
        let armfail_re = crate::regex::Regex::new("__GSD_(CHILD|RC|SRV)_ARM_FAILED_").unwrap();
        let loop_dead_boot_re = crate::regex::Regex::new("__GSD_LOOP_DONE_boot__").unwrap();
        let loop_dead_srv_re = crate::regex::Regex::new("__GSD_LOOP_DONE_srv__").unwrap();
        let base = log.len();
        crate::console::paced_send(&s, b"rc /boot/trace-boot.rc chain\r");
        // arm takes minutes under TCG stepping; fail fast if boot dies before
        // the rc arm completes or the guest reports an arm failure
        let adeadline = Instant::now() + Duration::from_secs(3600);
        loop {
            if Instant::now() >= adeadline {
                crate::console::fail(&log, "trace-syscalls", "chain never armed within 3600s", &mut err);
                return Err("chain never armed".into());
            }
            if panic_re.is_match(&log.tail(8192)) {
                crate::console::fail(&log, "trace-syscalls", "kernel fault during chain arming", &mut err);
                return Err("kernel fault during chain arming".into());
            }
            if log.search_from(&armed_re, base) {
                break;
            }
            if log.search_from(&armfail_re, base) {
                crate::console::fail(&log, "trace-syscalls", "guest reported an arm failure", &mut err);
                return Err("guest reported an arm failure".into());
            }
            // paqfs's main line exits right after forking its server (by
            // design) — only boot's or the server's early death is fatal
            if log.search_from(&loop_dead_boot_re, base) || log.search_from(&loop_dead_srv_re, base) {
                crate::console::fail(
                    &log,
                    "trace-syscalls",
                    "the boot/srv loop ended before arming completed (chain died — see the log for its fatal line)",
                    &mut err,
                );
                return Err("chain died during arming".into());
            }
            std::thread::sleep(Duration::from_secs(2));
        }
        eprintln!("== chain armed (boot/paqfs/srv/rc loops live)");

        // boot's progress prints localize a stall; termrc's stacksmoke
        // marker proves the D-15 binary ran in-chain
        for (rx, what) in [
            (crate::regex::Regex::new("paqfs\\.\\.\\.").unwrap(), "boot's paqfs... print"),
            (crate::regex::Regex::new("version\\.\\.\\.").unwrap(), "boot's version... print"),
            (
                crate::regex::Regex::new("init: starting /bin/rc").unwrap(),
                "init's starting-/bin/rc print",
            ),
            (
                crate::regex::Regex::new("stacksmoke: depth 64 ok").unwrap(),
                "termrc's stacksmoke marker",
            ),
        ] {
            if !expect_from(&log, &rx, base, 900, what, &mut err) {
                return Err(format!("missing {}", what));
            }
        }

        // the sourced sweep at OUR rc (the donor's devcons fails /dev/cons
        // reads by design — kbdfs territory — so the trace termrc sources
        // /boot/oursweep.rc via `rc -c`). Hard gates: the echo marker and
        // the teardown marker.
        let sweep_echo_re = crate::regex::Regex::new("^__GSD_SWEEP_ECHO__\r?$").unwrap();
        if !expect_from(&log, &sweep_echo_re, base, 900, "sweep echo marker", &mut err) {
            return Err("missing sweep echo marker".into());
        }
        eprintln!("== sweep: echo marker ok");

        // oursweep.rc ends with exit → rc dies → init's restart loop → the
        // watchdog lets sleep(17) land, then kills the chain. The donor
        // prompt can arrive in the SAME burst as CHAIN_DONE — capture the
        // base BEFORE waiting or the follow-up search misses it.
        let chain_done_re = crate::regex::Regex::new("^__GSD_CHAIN_DONE__\r?$").unwrap();
        let pbase = log.len();
        if !expect_from(&log, &chain_done_re, pbase, 1800, "chain teardown", &mut err) {
            return Err("missing chain teardown".into());
        }
        eprintln!("== chain traced and torn down");

        // donor shell resumes; run the standalone sweep traces
        let prompt_re = crate::console::prompt_re();
        if !expect_from(&log, &prompt_re, pbase, 180, "donor term% prompt", &mut err) {
            return Err("missing donor term% prompt".into());
        }
        crate::console::paced_send(&s, b"rc /boot/trace-boot.rc sweep\r");
        let all_done_re = crate::regex::Regex::new("^__GSD_ALL_DONE__\r?$").unwrap();
        let abase = log.len();
        if !expect_from(&log, &all_done_re, abase, 1800, "sweep traces", &mut err) {
            return Err("missing sweep traces".into());
        }
        eprintln!("== sweep binaries traced");
        std::fs::read(&cfg.runlog_bc).map_err(|e| format!("read runlog: {}", e))
    })();
    if let Some(s) = srv9.take() {
        procs.push(s);
    }
    result
}

// ---- boot-chain phase 5: parse + artifact -----------------------------------
fn parse_and_write_bootchain(cfg: &Cfg, capture: &[u8]) -> Result<(), String> {
    let start = find_subslice(capture, b"rc /boot/trace-boot.rc chain");
    let end = rfind_subslice(capture, b"__GSD_ALL_DONE__");
    let (start, end) = match (start, end) {
        (Some(s), Some(e)) if e > s => (s, e),
        _ => {
            return Err(format!(
                "boot-chain trace region not bracketed in the serial log (see {})",
                cfg.runlog_bc.display()
            ))
        }
    };
    let region = &capture[start..end];
    let defines_text = std::fs::read_to_string(&cfg.sysh)
        .map_err(|e| format!("read {}: {}", cfg.sysh.display(), e))?;
    let defines = load_sysh(&defines_text);
    let data = parse_chain_region(region, &defines)?;
    let names: std::collections::HashSet<&str> = data.counts.keys().map(|s| s.as_str()).collect();
    let new_names: Vec<&str> = names
        .iter()
        .filter(|n| !PHASE4_SET.contains(n))
        .copied()
        .collect();
    let text = artifact_chain(&data, &cfg.runlog_bc.to_string_lossy(), &utc_now_iso());
    std::fs::write(&cfg.artifact_bc, &text)
        .map_err(|e| format!("write {}: {}", cfg.artifact_bc.display(), e))?;
    eprintln!(
        "== artifact written: {} ({} syscalls, {} new vs Phase 4)",
        cfg.artifact_bc.display(),
        names.len(),
        new_names.len()
    );
    let mut rows: Vec<(&String, &u32)> = data.numbers.iter().collect();
    rows.sort_by_key(|(_, n)| **n);
    for (name, number) in rows {
        eprintln!("   {} {} (×{})", number, name, data.counts[name]);
    }
    Ok(())
}

fn mkdtemp(prefix: &str) -> Result<PathBuf, String> {
    let mut p = std::env::temp_dir();
    p.push(format!(
        "{}{}.{}",
        prefix,
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_nanos())
            .unwrap_or(0)
    ));
    std::fs::create_dir_all(&p).map_err(|e| e.to_string())?;
    Ok(p)
}

fn main_hello(cfg: &Cfg) -> Result<(), String> {
    preconditions(cfg)?;
    let tmpd = mkdtemp("trace-syscalls.")?;
    let r = (|| {
        let trace_bin = compile_tracehello(cfg, &tmpd)?;
        stage_and_rebake(cfg, &tmpd, &trace_bin)?;
        let capture = boot_and_trace(cfg, &tmpd)?;
        parse_and_write(cfg, &capture)
    })();
    let _ = std::fs::remove_dir_all(&tmpd);
    r?;
    eprintln!("== PASS: D-14 trace complete");
    Ok(())
}

fn main_bc(cfg: &Cfg) -> Result<(), String> {
    preconditions_bc(cfg)?;
    let tmpd = mkdtemp("trace-syscalls-bootchain.")?;
    let r = (|| {
        let pidwait_bin = compile_pidwait(cfg, &tmpd)?;
        stage_and_rebake_bc(cfg, &tmpd, &pidwait_bin)?;
        let capture = boot_and_trace_chain(cfg, &tmpd)?;
        parse_and_write_bootchain(cfg, &capture)
    })();
    let _ = std::fs::remove_dir_all(&tmpd);
    r?;
    eprintln!("== PASS: real-chain trace complete");
    Ok(())
}

pub fn run(args: &[String]) -> i32 {
    if args.iter().any(|a| a == "--help" || a == "-h") {
        eprint!("{}", USAGE);
        return 0;
    }
    let cfg = cfg();
    let r = if args.iter().any(|a| a == "--boot-chain") {
        main_bc(&cfg)
    } else {
        main_hello(&cfg)
    };
    match r {
        Ok(()) => 0,
        Err(e) => die(&e),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn defines() -> HashMap<String, u32> {
        // the shape of sys/src/libc/9syscall/sys.h, lowercase-keyed
        load_sysh(
            "#define\tSYSR1\t\t0\n\
             #define\t_ERRSTR\t\t1\n\
             #define\tBIND\t\t2\n\
             #define\tCHDIR\t\t3\n\
             #define\tCLOSE\t\t4\n\
             #define\tDUP\t\t5\n\
             #define\tALARM\t\t6\n\
             #define\tEXEC\t\t7\n\
             #define\tEXITS\t\t8\n\
             #define\tFAUTH\t\t10\n\
             #define\tSEGBRK\t\t12\n\
             #define\tOPEN\t\t14\n\
             #define\tOSEEK\t\t16\n\
             #define\tSLEEP\t\t17\n\
             #define\tRFORK\t\t19\n\
             #define\tPIPE\t\t21\n\
             #define\tCREATE\t\t22\n\
             #define\tFD2PATH\t\t23\n\
             #define\tBRK_\t\t24\n\
             #define\tREMOVE\t\t25\n\
             #define\tNOTIFY\t\t28\n\
             #define\tNOTED\t\t29\n\
             #define\tUNMOUNT\t\t35\n\
             #define\tSEEK\t\t39\n\
             #define\tFVERSION\t\t40\n\
             #define\tERRSTR\t\t41\n\
             #define\tSTAT\t\t42\n\
             #define\tFSTAT\t\t43\n\
             #define\tMOUNT\t\t46\n\
             #define\tAWAIT\t\t47\n\
             #define\tPREAD\t\t50\n\
             #define\tPWRITE\t\t51\n",
        )
    }

    // ---- ENTRY parse fixtures (committed-log fragment shapes) -------------

    #[test]
    fn entry_re_matches_real_shapes() {
        let rx = entry_re();
        // with args
        let t = b"196 tracehello Pwrite 14918 1  0x7fffefd38/\"hello.aarch64.harvey.\" 21 -1";
        let m = rx.find(t).unwrap();
        assert_eq!(m.group_str(1, t), Some("196"));
        assert_eq!(m.group_str(2, t), Some("tracehello"));
        assert_eq!(m.group_str(3, t), Some("Pwrite"));
        assert_eq!(m.group_str(4, t), Some("14918"));
        // pc as the last field (end-of-line case)
        let t = b"196 tracehello Exits 14b6c";
        assert!(rx.is_match(t));
        // return fragments never match
        assert!(!rx.is_match(b" = 21 \"\" 32218768000 32218838000"));
        assert!(!rx.is_match(b" = 12 \"\" 32235168000 32235186000"));
    }

    #[test]
    fn resolve_name_variants() {
        let d = defines();
        assert_eq!(resolve(&d, "pwrite"), Some((51, "pwrite".to_string())));
        assert_eq!(resolve(&d, "brk"), Some((24, "brk_".to_string())));
        assert_eq!(resolve(&d, "open"), Some((14, "open".to_string())));
        assert_eq!(resolve(&d, "nosuch"), None);
    }

    #[test]
    fn load_sysh_lowercases_and_parses() {
        let d = defines();
        assert_eq!(d.get("pwrite"), Some(&51));
        assert_eq!(d.get("brk_"), Some(&24));
        assert_eq!(d.get("_errstr"), Some(&1));
        assert!(d.get("PWRITE").is_none(), "keys are lowercased");
    }

    #[test]
    fn hello_region_extracts_first_use_order() {
        let region = "\
term% rc /boot/trace.rc 196\r\n\
196 tracehello Pwrite 14918 1  0x7fffefd38/\"hello.aarch64.harvey.\" 21 -1hello aarch64 harvey\r\n\
 = 21 \"\" 32218768000 32218838000\r\n\
196 tracehello Pwrite 14918 1  0x7fffefd38/\"tracehello.second.print.\" 24 -1\r\n\
 = 24 \"\" 32224238000 32224298000\r\n\
196 tracehello Open 11ae0 0x20000/\"#c/pid\" 0x0 = 3 \"\" 32229902000 32229949008\r\n\
196 tracehello Pread 14928 3 0x7fffefe84 20 -1 0x7fffefe84/\"........196.\" 20 -1 = 12 \"\" 32235168000 32235186000\r\n\
196 tracehello Close 11af0 3 = 0 \"\" 32240265008 32240272000\r\n\
196 tracehello Exits 14b6c 0/\"\"\r\n\
__GSD_TRACE_LOOP_DONE__\r\n";
        let ordered = parse_hello_region(region, &defines()).expect("parses");
        assert_eq!(
            ordered,
            vec![
                (51, "pwrite".to_string()),
                (14, "open".to_string()),
                (50, "pread".to_string()),
                (4, "close".to_string()),
                (8, "exits".to_string()),
            ]
        );
    }

    #[test]
    fn hello_region_requires_pwrite_and_exits() {
        let region = "196 tracehello Open 11ae0 0x20000/\"#c/pid\" 0x0\n196 tracehello Close 11af0 3\n";
        let err = parse_hello_region(region, &defines()).unwrap_err();
        assert!(err.contains("pwrite"), "err: {}", err);
    }

    #[test]
    fn hello_region_rejects_huh_and_unknown() {
        let err = parse_hello_region("1 t huh? 14b6c\n", &defines()).unwrap_err();
        assert!(err.contains("huh?"));
        let err = parse_hello_region("1 t Frobnicate 14b6c\n", &defines()).unwrap_err();
        assert!(err.contains("unknown syscall name: Frobnicate"));
    }

    #[test]
    fn hello_region_empty_is_an_error() {
        let err = parse_hello_region("no fragments here\n", &defines()).unwrap_err();
        assert!(err.contains("no entry fragments parsed"));
    }

    #[test]
    fn artifact_hello_byte_shape() {
        let ordered = vec![
            (51u32, "pwrite".to_string()),
            (14, "open".to_string()),
            (50, "pread".to_string()),
            (4, "close".to_string()),
            (8, "exits".to_string()),
        ];
        let text = artifact_hello(&ordered, "/x/trace-run.log", "2026-11-02T12:33:23Z");
        let lines: Vec<&str> = text.lines().collect();
        assert_eq!(lines[0], "# date: 2026-11-02T12:33:23Z");
        assert_eq!(
            lines[1],
            "# donor pin: 350266104f1fed81c78c3d05fa44f523bec0ae4d (9front branch front)"
        );
        assert!(lines[2].starts_with("# target: /boot/tracehello"));
        assert!(lines[3].starts_with("# method: startsyscall+/proc/N/syscall"));
        assert_eq!(
            lines[4],
            "# serial log: /x/trace-run.log (gitignored .build evidence)"
        );
        assert_eq!(&lines[5..], ["51 pwrite", "14 open", "50 pread", "4 close", "8 exits"]);
    }

    // ---- boot-chain parser fixtures ----------------------------------------

    const CHAIN_FIXTURE: &str = "\
term% rc /boot/trace-boot.rc chain\r\n\
__GSD_CHAIN_LAUNCH__\r\n\
__GSD_ARM_boot_234__\r\n\
__GSD_ARM_paqfs_1259__\r\n\
__GSD_ARM_srv_1741__\r\n\
__GSD_ARM_rc_3413__\r\n\
__GSD_CHAIN_ARMED__\r\n\
__GSD_FRAG_234__234 rc Create 265b0 0x34900/\"/env/a\" 0x1 0x1b6\n\
__GSD_FRAG_234__ = 5 \"\" 27470231008 27470331008\n\
__GSD_FRAG_234__234 rc Close 265c0 5\n\
__GSD_FRAG_234__ = 0 \"\" 27481985008 27482000000\n\
__GSD_FRAG_234__234 boot Close 11af0 0\n\
__GSD_FRAG_234__234 boot Close 11af0 1\n\
__GSD_FRAG_234__234 boot Close 11af0 2\n\
__GSD_FRAG_234__234 boot Bind 12070 0 0x34830/\"#c\" 0x34870/\"/dev\" -1 0\n\
__GSD_FRAG_234__234 boot Open 11ae0 0x20000/\"/dev/cons\" 0x0\n\
__GSD_FRAG_234__234 boot Open 11ae0 0x20000/\"/dev/cons\" 0x1\n\
__GSD_FRAG_234__234 boot Open 11ae0 0x20000/\"/dev/cons\" 0x2\n\
__GSD_FRAG_234__234 boot Fversion 14c10 5 8192 0x34e20/\"9P2000\"\n\
__GSD_FRAG_234__234 boot Pipe 14230 0x349a0\n\
__GSD_FRAG_234__234 boot Dup 11b60 5 0\n\
__GSD_FRAG_234__234 boot Mount 14570 5 0 0x34900/\"/root\" 0 0x34a00/\"\"\n\
__GSD_FRAG_234__234 boot Stat 14a00 0x34800/\"/root\" 0x34b00 99\n\
__GSD_FRAG_234__234 boot Pwrite 14918 1 0x7fffefd38/\"x\" 1 -1\n\
__GSD_FRAG_234__234 boot Exits 14b6c 0/\"\"\n\
__GSD_FRAG_1259__1259 paqfs Open 11ae0 0x20000/\"/boot/ourbootfs.paq\" 0x0\n\
__GSD_FRAG_1259__1259 paqfs Pread 14928 3 0x7fffefe84 20 -1\n\
__GSD_FRAG_1259__1259 paqfs Close 11af0 3\n\
__GSD_SWEEP_BEGIN_ourecho__\r\n\
__GSD_FRAG_9999__9999 ourecho Pwrite 14918 1 0x7fffefd38/\"__GSD_SWEEP_ECHO_OUT__\" 22 -1\n\
__GSD_FRAG_9999__9999 ourecho Exits 14b6c 0/\"\"\n\
__GSD_SWEEP_DONE_ourecho__\r\n\
__GSD_ALL_DONE__\r\n";

    #[test]
    fn chain_region_counts_roles_streams() {
        let data = parse_chain_region(CHAIN_FIXTURE.as_bytes(), &defines()).expect("parses");
        // per-name counts
        assert_eq!(data.counts.get("close"), Some(&5)); // 1 rc + 3 boot + 1 paqfs... see fixture
        assert_eq!(data.counts.get("open"), Some(&4));
        assert_eq!(data.counts.get("pwrite"), Some(&2));
        assert_eq!(data.counts.get("exits"), Some(&2));
        assert_eq!(data.counts.get("bind"), Some(&1));
        assert_eq!(data.counts.get("pipe"), Some(&1));
        assert_eq!(data.counts.get("fversion"), Some(&1));
        assert_eq!(data.counts.get("mount"), Some(&1));
        assert_eq!(data.counts.get("stat"), Some(&1));
        assert_eq!(data.counts.get("pread"), Some(&1));
        assert_eq!(data.counts.get("dup"), Some(&1));
        assert_eq!(data.counts.get("create"), Some(&1));
        // numbers resolved
        assert_eq!(data.numbers.get("pwrite"), Some(&51));
        assert_eq!(data.numbers.get("bind"), Some(&2));
        // roles
        assert_eq!(data.roles.get(&234), Some(&"boot".to_string()));
        assert_eq!(data.roles.get(&1259), Some(&"paqfs".to_string()));
        // per-role totals
        assert_eq!(data.per_role.get("boot"), Some(&16));
        assert_eq!(data.per_role.get("paqfs"), Some(&3));
        assert_eq!(data.per_role.get("sweep:ourecho"), Some(&2));
        // boot stream in order (the opencons run lands at offset 2 here
        // after the launcher's rc bookkeeping close×2)
        assert!(data.boot_stream.len() >= 10);
        let (at, adds) = opencons_analysis(&data.boot_stream);
        assert!(at >= 0, "opencons run found in the boot stream");
        assert!(adds.is_empty());
    }

    #[test]
    fn chain_region_missing_required_is_an_error() {
        // no bind/pipe/fversion/mount/dup in this region
        let region = "\
__GSD_ARM_boot_234__\r\n\
__GSD_FRAG_234__234 boot Pwrite 14918 1 0x1/\"x\" 1 -1\n\
__GSD_FRAG_234__234 boot Exits 14b6c 0/\"\"\n";
        let err = parse_chain_region(region.as_bytes(), &defines()).unwrap_err();
        assert!(err.contains("measured set lacks"), "err: {}", err);
    }

    #[test]
    fn chain_region_return_fragments_and_pid_mismatch_skipped() {
        let region = "\
__GSD_ARM_boot_234__\r\n\
__GSD_FRAG_234__ = 5 \"\" 27470231008 27470331008\n\
__GSD_FRAG_234__garbage that is not an entry at all\n\
__GSD_FRAG_234__999 rc Close 265c0 5\n\
__GSD_FRAG_234__234 boot Close 265c0 5\n\
__GSD_FRAG_234__234 boot Bind 12070 0 0x34830/\"#c\" 0x34870/\"/dev\" -1 0\n\
__GSD_FRAG_234__234 boot Pipe 14230 0x349a0\n\
__GSD_FRAG_234__234 boot Fversion 14c10 5 8192 0x34e20/\"9P2000\"\n\
__GSD_FRAG_234__234 boot Mount 14570 5 0 0x34900/\"/root\" 0 0x34a00/\"\"\n\
__GSD_FRAG_234__234 boot Dup 11b60 5 0\n\
__GSD_FRAG_234__234 boot Stat 14a00 0x34800/\"/root\" 0x34b00 99\n\
__GSD_FRAG_234__234 boot Pwrite 14918 1 0x7fffefd38/\"x\" 1 -1\n\
__GSD_FRAG_234__234 boot Exits 14b6c 0/\"\"\n";
        let data = parse_chain_region(region.as_bytes(), &defines()).expect("parses");
        assert_eq!(data.malformed, 2, "glued line + pid mismatch skipped");
        assert_eq!(data.counts.get("close"), Some(&1));
    }

    #[test]
    fn artifact_chain_byte_shape() {
        let data = parse_chain_region(CHAIN_FIXTURE.as_bytes(), &defines()).unwrap();
        let text = artifact_chain(&data, "/x/bootchain-trace-run.log", "2026-11-03T04:50:25Z");
        let lines: Vec<&str> = text.lines().collect();
        assert_eq!(lines[0], "# date: 2026-11-03T04:50:25Z");
        assert!(lines[1].starts_with("# donor pin: 350266104f"));
        assert!(text.contains("# rig: build/aarch64/trace-syscalls.py --boot-chain (05-03)"));
        assert!(text.contains("# traced processes: boot pid 234; paqfs pid 1259"));
        assert!(text.contains("boot=16"));
        // rows sorted by number, name is the sys.h name
        assert!(text.contains("\n2 bind\n"));
        assert!(text.contains("\n51 pwrite\n"));
        assert!(text.contains("# NEW vs the Phase-4 implemented set"));
        assert!(text.contains("#   3 chdir") == false, "chdir was not traced in the fixture");
        assert!(text.contains("#   22 create (1 occurrences)"));
        assert!(text.contains(
            "#   none — opencons's close×3/bind/open×3 appear as a contiguous run"
        ));
    }
}
