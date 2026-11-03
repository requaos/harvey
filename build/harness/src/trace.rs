//! trace.rs — harness trace-syscalls: measure the syscall footprint on the
//! 9front donor kernel (port of trace-syscalls.py; Task 2 of the plan).
//!
//! RED-phase stub for Task 1: only the CLI surface exists.

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
