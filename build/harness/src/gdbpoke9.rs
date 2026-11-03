//! gdbpoke9.rs — poke guest memory through qemu's gdbstub with a raw RSP
//! (gdb remote serial protocol) client (port of gdbpoke9.py).
//!
//! Written for the boot harness: qemu 11.1.2's GICv3 model resets
//! GICR_WAKER.ProcessorSleep=1 (spec-accurate) and the pinned 9front donor's
//! gic.c never clears it. With the redistributor asleep, PPI interrupts (the
//! CNTV timer, INTID 27) never fire: no ticks, so devuart's uartclock()
//! never flushes staged console input and the boot parks forever at the
//! bootargs prompt. The poke writes 0 to GICR0 WAKER through the guest's own
//! kernel VA mapping (VIRTIO=0xFFFFFFFFB0000000 + 0xA0000 GICR + 0x14).
//!
//! usage: harness gdbpoke9 --sock PATH --watch-file LOG [--watch-str STR]
//!        [--addr HEX] [--value HEX] [--bytes N] [--deadline SECS]
//! exits 0 once the write lands, 1 on timeout/error, 2 on bad args.

use std::io::Write;

pub const DEFAULT_ADDR: u64 = 0xFFFFFFFF_B00A_0014; // VIRTIO + GICR0 + WAKER
pub const DEFAULT_WATCH: &str = "bootargs is";

/// RED-phase stub: parses args (the exit-2 surface is real), then reports
/// success without doing anything — the GREEN commit implements the RSP
/// client and the watch-file gating.
pub fn run(args: &[String]) -> i32 {
    let mut err = std::io::stderr();
    run_io(args, &mut err)
}

pub fn run_io(args: &[String], err: &mut dyn Write) -> i32 {
    let mut sock: Option<String> = None;
    let mut watch_file: Option<String> = None;
    let mut i = 0;
    while i < args.len() {
        let a = args[i].as_str();
        match a {
            "--sock" | "--addr" | "--value" | "--bytes" | "--watch-file" | "--watch-str"
            | "--deadline" => {
                if a == "--sock" {
                    sock = args.get(i + 1).cloned();
                }
                if a == "--watch-file" {
                    watch_file = args.get(i + 1).cloned();
                }
                i += 2;
            }
            _ => {
                let _ = writeln!(err, "gdbpoke9: unknown arg {}", a);
                return 2;
            }
        }
    }
    if sock.is_none() || watch_file.is_none() {
        let _ = writeln!(err, "gdbpoke9: --sock and --watch-file are required");
        return 2;
    }
    0 // RED stub: claims success without poking
}
