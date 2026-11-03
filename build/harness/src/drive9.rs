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
