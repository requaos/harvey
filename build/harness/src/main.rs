// harness — the Harvey build/aarch64 host harness as ONE std-only Rust
// binary. Subcommands are drop-in
// CLI-compatible replacements for the retired Python tools:
//
//   harness srv9 serve --root DIR [--host H] [--port P] [--writable-prefix P ...]
//   harness drive9 --serial SOCK --qmp SOCK --log FILE [--budget SECS] [--steps FILE]
//   harness gdbpoke9 --sock PATH --watch-file LOG [--watch-str STR] ...
//   harness mkfs9 [-a] [-s oldroot] [-d dest] proto ...
//   harness trace-syscalls [--boot-chain] [--help]
//
// Exit-code discipline everywhere: 0 ok / 1 fail / 2 usage.

mod console;
mod drive9;
mod gdbpoke9;
mod mkfs9;
mod regex;
mod srv9;
mod trace;

const USAGE: &str = "usage: harness <srv9|trace-syscalls|gdbpoke9|mkfs9|drive9> ...\n";

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 2 {
        eprint!("{}", USAGE);
        std::process::exit(2);
    }
    let code = match args[1].as_str() {
        "srv9" => srv9::run(&args[2..]),
        "trace-syscalls" => trace::run(&args[2..]),
        "gdbpoke9" => gdbpoke9::run(&args[2..]),
        "mkfs9" => mkfs9::run(&args[2..]),
        "drive9" => drive9::run(&args[2..]),
        other => {
            eprintln!("harness: unknown subcommand {}", other);
            eprint!("{}", USAGE);
            2
        }
    };
    std::process::exit(code);
}
