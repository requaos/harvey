//! drive9.rs — serial-console driver for the 9front donor kernel boot
//! (port of drive9.py + the run-gate.sh gatedrive9.py and subset-exec.sh
//! subsetdrive9.py generated heredocs, generalized as --steps FILE).
//!
//! Base mode = drive9.py exactly: attach the capture BEFORE the guest runs
//! (qemu is paused with -S), resume via QMP "cont", answer the bootargs/auth
//! prompts, prove the interactive rc shell (rc-caret-split probe), set and
//! prove the term% prompt (anchored, order-dependent). Exits 0/1/2.
//!
//! --steps FILE = the gatedrive9/subsetdrive9 post-shell phase generalized:
//! a tab-separated step table (cmd, echo-pattern or '-', out-pattern,
//! timeout-secs, label; '#' comments; default echo = first 16 bytes of cmd,
//! metachar-escaped), paced sends (50ms/byte), echo-verified delivery
//! (3 attempts; echo failure retries, clean echo + missing out-pattern is a
//! genuine failure — no retry), panic fast-fail throughout, per-step
//! 'drive9: step i/n OK (label)'.
//!
//! usage: harness drive9 --serial SOCK --qmp SOCK --log FILE [--budget SECS] [--steps FILE]

use std::io::Write;
use std::os::unix::net::UnixStream;
use std::path::Path;
use std::time::{Duration, Instant};

use crate::console;
use crate::regex::{escape_lit, Regex};

/// One row of the --steps table: tab-separated
/// cmd \t echo-pattern-or-'-' \t out-pattern \t timeout-secs \t label.
#[derive(Debug)]
pub struct Step {
    pub cmd: Vec<u8>,
    pub echo: Option<Regex>,
    pub out: Regex,
    pub timeout: u64,
    pub label: String,
}

/// Unescape the cmd field: \r \n \\ (the only escapes the generators emit).
fn unescape_cmd(s: &str) -> Vec<u8> {
    let b = s.as_bytes();
    let mut out = Vec::with_capacity(b.len());
    let mut i = 0;
    while i < b.len() {
        if b[i] == b'\\' && i + 1 < b.len() {
            match b[i + 1] {
                b'r' => out.push(b'\r'),
                b'n' => out.push(b'\n'),
                b'\\' => out.push(b'\\'),
                other => {
                    out.push(b'\\');
                    out.push(other);
                }
            }
            i += 2;
        } else {
            out.push(b[i]);
            i += 1;
        }
    }
    out
}

/// Parse a steps file: tab-separated rows
/// `cmd \t echo-pattern-or-'-' \t out-pattern \t timeout-secs \t label`;
/// '#' comment lines and blank lines skipped.
pub fn parse_steps(text: &str) -> Result<Vec<Step>, String> {
    let mut steps = Vec::new();
    for (lineno, line) in text.lines().enumerate() {
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        let fields: Vec<&str> = line.split('\t').collect();
        if fields.len() != 5 {
            return Err(format!(
                "line {}: want 5 tab-separated fields, have {}",
                lineno + 1,
                fields.len()
            ));
        }
        let cmd = unescape_cmd(fields[0]);
        let echo = if fields[1] == "-" {
            None
        } else {
            Some(
                Regex::new(fields[1])
                    .map_err(|e| format!("line {}: echo pattern: {}", lineno + 1, e))?,
            )
        };
        let out = Regex::new(fields[2])
            .map_err(|e| format!("line {}: out pattern: {}", lineno + 1, e))?;
        let timeout: u64 = fields[3]
            .parse()
            .map_err(|_| format!("line {}: bad timeout '{}'", lineno + 1, fields[3]))?;
        let label = fields[4].to_string();
        steps.push(Step {
            cmd,
            echo,
            out,
            timeout,
            label,
        });
    }
    Ok(steps)
}

pub fn run(args: &[String]) -> i32 {
    let mut err = std::io::stderr();
    let mut serial: Option<String> = None;
    let mut qmp: Option<String> = None;
    let mut logpath: Option<String> = None;
    let mut budget: u64 = 600;
    let mut steps: Option<String> = None;
    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "--serial" => {
                serial = args.get(i + 1).cloned();
                i += 2;
            }
            "--qmp" => {
                qmp = args.get(i + 1).cloned();
                i += 2;
            }
            "--log" => {
                logpath = args.get(i + 1).cloned();
                i += 2;
            }
            "--budget" => {
                budget = match args.get(i + 1).and_then(|b| b.parse().ok()) {
                    Some(b) => b,
                    None => {
                        let _ = writeln!(err, "drive9: --budget requires a numeric value");
                        return 2;
                    }
                };
                i += 2;
            }
            "--steps" => {
                steps = args.get(i + 1).cloned();
                i += 2;
            }
            other => {
                let _ = writeln!(err, "drive9: unknown arg {}", other);
                return 2;
            }
        }
    }
    let (serial, qmp, logpath) = match (serial, qmp, logpath) {
        (Some(s), Some(q), Some(l)) => (s, q, l),
        _ => {
            let _ = writeln!(err, "drive9: --serial, --qmp and --log are required");
            return 2;
        }
    };

    let step_table = match steps {
        Some(p) => match std::fs::read_to_string(&p) {
            Ok(text) => match parse_steps(&text) {
                Ok(t) => Some(t),
                Err(e) => {
                    let _ = writeln!(err, "drive9: steps file {}: {}", p, e);
                    return 2;
                }
            },
            Err(e) => {
                let _ = writeln!(err, "drive9: cannot read steps file {}: {}", p, e);
                return 2;
            }
        },
        None => None,
    };

    let deadline = Instant::now() + Duration::from_secs(budget);
    let log = match console::Log::new(Path::new(&logpath), 512 * 1024, 256 * 1024) {
        Ok(l) => l,
        Err(e) => {
            let _ = writeln!(err, "drive9: cannot open log {}: {}", logpath, e);
            return 1;
        }
    };

    // 1. attach the capture BEFORE the guest runs (qemu is paused with -S;
    //    the chardev socket already exists)
    let mut sopt = None;
    while Instant::now() < deadline {
        match UnixStream::connect(&serial) {
            Ok(s) => {
                sopt = Some(s);
                break;
            }
            Err(_) => std::thread::sleep(Duration::from_millis(500)),
        }
    }
    let Some(s) = sopt else {
        console::fail(&log, "drive9", &format!("serial socket {} never appeared", serial), &mut err);
        return 1;
    };
    console::spawn_reader(s.try_clone().unwrap(), log.clone());

    // 2. resume the guest
    if let Err(e) = console::qmp_cont(Path::new(&qmp)) {
        console::fail(&log, "drive9", &format!("qmp cont failed: {}", e), &mut err);
        return 1;
    }
    let _ = writeln!(err, "drive9: capture attached, guest resumed (budget {}s)", budget);

    // 3-5. the boot drive: bootargs → auth → shell probe → prompt proof
    if console::drive_boot(&s, &log, deadline, budget, "drive9", console::PromptProbe::Marker, &mut err).is_err() {
        return 1;
    }

    // 6. the post-shell step table (the gatedrive9/subsetdrive9 phase)
    if let Some(steps) = step_table {
        let n = steps.len();
        for (idx, step) in steps.iter().enumerate() {
            if Instant::now() > deadline {
                console::fail(
                    &log,
                    "drive9",
                    &format!("budget exhausted mid-exercise (step {} {})", idx + 1, step.label),
                    &mut err,
                );
                return 1;
            }
            let base = log.len();
            let default_echo;
            let echo_re = match &step.echo {
                Some(r) => r,
                None => {
                    // default: first 16 bytes of cmd, metachar-escaped
                    let first = &step.cmd[..step.cmd.len().min(16)];
                    default_echo = Regex::new(&escape_lit(first)).unwrap();
                    &default_echo
                }
            };
            if !console::send_verified(
                &s,
                &log,
                &step.cmd,
                echo_re,
                &step.out,
                Duration::from_secs(step.timeout),
                base,
                &format!("step {} ({})", idx + 1, step.label),
                "drive9",
                &mut err,
            ) {
                return 1;
            }
            let _ = writeln!(err, "drive9: step {}/{} OK ({})", idx + 1, n, step.label);
        }
    }
    0
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_steps_basic_table() {
        let text = "# a comment\n\
                    \n\
                    /boot/hello\\r\t-\thello aarch64 harvey\t120\t/boot/hello\n\
                    echo __GSD_EXIT__$status\\r\techo __GSD_EXIT__\t^__GSD_EXIT__\\r?$\t60\texit-status probe\n";
        let steps = parse_steps(text).expect("parses");
        assert_eq!(steps.len(), 2);
        assert_eq!(steps[0].cmd, b"/boot/hello\r");
        assert!(steps[0].echo.is_none(), "'-' means the default echo pattern");
        assert_eq!(steps[0].timeout, 120);
        assert_eq!(steps[0].label, "/boot/hello");
        assert_eq!(steps[1].cmd, b"echo __GSD_EXIT__$status\r");
        assert!(steps[1].echo.is_some(), "explicit echo pattern kept");
        assert_eq!(steps[1].label, "exit-status probe");
    }

    #[test]
    fn parse_steps_default_echo_matches_first_16_bytes() {
        let text = "/boot/hls /tmp/subset\\r\t-\t^/tmp/subset/moved\\r?$\t60\tls verifies mv\n";
        let steps = parse_steps(text).expect("parses");
        let echo = steps[0].echo.as_ref();
        assert!(echo.is_none());
        // the default (computed at drive time): first 16 bytes, escaped
        let def = crate::regex::Regex::new(&crate::regex::escape_lit(&steps[0].cmd[..16])).unwrap();
        assert!(def.is_match(b"term% /boot/hls /tmp/subset\r\n"));
        assert!(!def.is_match(b"term% XbootXhls /tmp/subset\r\n"));
    }

    #[test]
    fn parse_steps_out_patterns_compile_and_match() {
        // the real subset-exec patterns must all compile in our engine
        let pats = [
            "^__SUBSET_SENTINEL__\\r?$",
            "^/boot\\r?$",
            "^alpha bravo charlie\\r?$",
            "^ *2\\r?$",
            "(UTC|GMT) 20[0-9][0-9]\\r?$",
            "\\src\\r?$",
            "^term% ",
            "\\bhfactotum\\b",
            "usage: .*hipconfig",
            "^SUBSET-OK\\r?$",
        ];
        for p in pats {
            crate::regex::Regex::new(p).unwrap_or_else(|e| panic!("{}: {}", p, e));
        }
    }

    #[test]
    fn parse_steps_rejects_malformed_rows() {
        // too few fields
        assert!(parse_steps("cmd\\r\t-\tout\n").is_err());
        // bad timeout
        assert!(parse_steps("cmd\\r\t-\tout\tNaN\tlabel\n").is_err());
        // bad regex
        assert!(parse_steps("cmd\\r\t-\t(\t60\tlabel\n").is_err());
    }

    #[test]
    fn arg_errors_exit_2() {
        assert_eq!(run(&[]), 2);
        assert_eq!(
            run(&["--serial".to_string(), "/x".to_string()]),
            2,
            "missing --qmp/--log"
        );
        assert_eq!(
            run(&["--bogus".to_string(), "1".to_string()]),
            2
        );
    }
}
