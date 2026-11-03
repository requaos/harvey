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
    _region: &str,
    _defines: &HashMap<String, u32>,
) -> Result<Vec<(u32, String)>, String> {
    Err("unimplemented (RED stub)".to_string())
}

/// Hello-path artifact text (byte-shape of 04-01-d14-trace.txt).
pub fn artifact_hello(_ordered: &[(u32, String)], _runlog: &str, _now_iso: &str) -> String {
    String::new() // RED stub
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
    _region: &[u8],
    _defines: &HashMap<String, u32>,
) -> Result<ChainData, String> {
    Err("unimplemented (RED stub)".to_string())
}

/// The opencons coverage-boundary analysis on the boot pid's stream:
/// the contiguous close×3/bind/open×3 run (boot.c:38-44). Returns
/// (opencons_at, source_additions).
pub fn opencons_analysis(_boot_stream: &[String]) -> (i64, Vec<(&'static str, &'static str)>) {
    (-1, Vec::new()) // RED stub
}

/// Boot-chain artifact text (byte-shape of 05-03-trace.txt).
pub fn artifact_chain(_data: &ChainData, _runlog_bc: &str, _now_iso: &str) -> String {
    String::new() // RED stub
}

// ---------------------------------------------------------------------------
// Live orchestration — the GREEN commit lands this; the RED stub dies.
// ---------------------------------------------------------------------------

const USAGE: &str = "usage: harness trace-syscalls [--boot-chain]\n\
\n\
\x20 (default)     the 04-01 hello-path trace → 04-01-d14-trace.txt\n\
\x20 --boot-chain  the 05-03 real-chain trace (boot/init/paqfs/rc + sweep)\n\
\x20               → 05-03-trace.txt\n\
\n\
Env overrides: HARVEY, HARVEY_VM, BOOT_BUDGET, SRV9_PORT, TRACE_OUT.\n";

pub fn run(args: &[String]) -> i32 {
    if args.iter().any(|a| a == "--help" || a == "-h") {
        eprint!("{}", USAGE);
        return 0;
    }
    eprintln!("trace-syscalls: error: not implemented (RED stub)");
    1
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
