//! drive9.rs — serial-console driver for the 9front donor kernel boot
//! (port of drive9.py + the run-gate.sh gatedrive9.py and subset-exec.sh
//! subsetdrive9.py generated heredocs, generalized as --steps FILE).
//!
//! usage: harness drive9 --serial SOCK --qmp SOCK --log FILE [--budget SECS] [--steps FILE]
//!
//! RED-phase stub: the arg/exit-2 surface is real; the drive is not.

use std::io::Write;

/// One row of the --steps table: tab-separated
/// cmd \t echo-pattern-or-'-' \t out-pattern \t timeout-secs \t label.
#[derive(Debug)]
pub struct Step {
    pub cmd: Vec<u8>,
    pub echo: Option<crate::regex::Regex>,
    pub out: crate::regex::Regex,
    pub timeout: u64,
    pub label: String,
}

/// Parse a steps file. RED stub: always yields an empty table.
pub fn parse_steps(_text: &str) -> Result<Vec<Step>, String> {
    Ok(Vec::new())
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
    if serial.is_none() || qmp.is_none() || logpath.is_none() {
        let _ = writeln!(err, "drive9: --serial, --qmp and --log are required");
        return 2;
    }
    let _ = (budget, steps);
    1 // RED stub: the drive is not implemented
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
