//! regex.rs — std-only byte-oriented backtracking regex engine (D-02 forbids
//! the regex crate). Covers exactly the pattern families the harness drivers
//! use:
//!
//!   - multiline `^` / `$` anchors (^ matches at start or after \n; $ matches
//!     at end or before \n — every anchor use in this codebase is Python
//!     (?m)-style)
//!   - literal bytes, `.` (any byte except \n, Python default)
//!   - escapes: \r \n \t \\ \d \D \s \S \w \W \b \B, and escaped literals
//!     (\( \. \$ …)
//!   - [...] classes incl. ranges and negation
//!   - greedy * ? + with backtracking
//!   - (a|b) alternation, (?:...) non-capturing groups, (...) capture groups
//!   - case-insensitive mode (re.I equivalent — the one ci use is
//!     'panic|trap:', pure literals)
//!
//! Threat T-GIQ-04: matching runs on bounded buffers with a step cap; a
//! pathological pattern returns no-match instead of hanging.

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Span {
    pub start: usize,
    pub end: usize,
}

#[derive(Clone, Debug)]
pub struct Match {
    pub span: Span,
    /// groups[0] is the whole match; groups[n] is capture group n.
    pub groups: Vec<Option<Span>>,
}

impl Match {
    pub fn group<'t>(&self, n: usize, text: &'t [u8]) -> Option<&'t [u8]> {
        self.groups
            .get(n)
            .and_then(|g| *g)
            .map(|s| &text[s.start..s.end])
    }
    pub fn group_str<'t>(&self, n: usize, text: &'t [u8]) -> Option<&'t str> {
        self.group(n, text)
            .and_then(|b| std::str::from_utf8(b).ok())
    }
}

#[derive(Debug)]
pub struct Regex {
    // RED-phase stub: the real engine lands in the GREEN commit.
}

impl Regex {
    pub fn new(_pat: &str) -> Result<Regex, String> {
        Ok(Regex {})
    }
    /// Case-insensitive variant (re.I).
    pub fn new_ci(_pat: &str) -> Result<Regex, String> {
        Ok(Regex {})
    }
    pub fn is_match(&self, _text: &[u8]) -> bool {
        false
    }
    pub fn is_match_at(&self, _text: &[u8], _start: usize) -> bool {
        false
    }
    pub fn find(&self, _text: &[u8]) -> Option<Match> {
        None
    }
    pub fn find_at(&self, _text: &[u8], _start: usize) -> Option<Match> {
        None
    }
}

/// Escape every regex metacharacter in `bytes` (the drive9 --steps default
/// echo pattern = first 16 bytes of the command, metachar-escaped, mirroring
/// Python's re.escape: only [A-Za-z0-9_] pass through unescaped).
pub fn escape_lit(bytes: &[u8]) -> String {
    let mut out = String::new();
    for &b in bytes {
        if b.is_ascii_alphanumeric() || b == b'_' {
            out.push(b as char);
        } else {
            out.push('\\');
            out.push(b as char);
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    fn m(pat: &str) -> Regex {
        Regex::new(pat).expect("pattern compiles")
    }

    // ---- PANIC_RE: 'panic|trap:' case-insensitive ------------------------
    #[test]
    fn panic_ci_alternation_matches() {
        let rx = Regex::new_ci("panic|trap:").unwrap();
        assert!(rx.is_match(b"kernel panic at mmu.c"));
        assert!(rx.is_match(b"PANIC: bad magic"));
        assert!(rx.is_match(b"sys: trap: breakpoint"));
        assert!(rx.is_match(b"sys: TRAP: fault"));
    }
    #[test]
    fn panic_ci_alternation_nonmatches() {
        let rx = Regex::new_ci("panic|trap:").unwrap();
        assert!(!rx.is_match(b"all is well"));
        assert!(!rx.is_match(b"pancake")); // 'panc' is not 'panic'
        assert!(!rx.is_match(b"trap door")); // no colon after trap
    }

    // ---- BOOTARGS_RE: 'bootargs is \(tcp' ---------------------------------
    #[test]
    fn bootargs_pattern() {
        let rx = m("bootargs is \\(tcp");
        assert!(rx.is_match(b"bootargs is (tcp, local!...)\n"));
        assert!(!rx.is_match(b"bootargs is tcp"));
        assert!(!rx.is_match(b"bootargs are (tcp"));
    }

    // ---- AUTH_RE -----------------------------------------------------------
    #[test]
    fn auth_pattern() {
        let rx = m("auth address is\\?");
        assert!(rx.is_match(b" auth address is? [10.0.2.100]: "));
        assert!(!rx.is_match(b"auth address is")); // literal ? required
    }

    // ---- SHELL_RE: '^__GSD_SHELL_OK__\r?$' + WR-04 echo-attack discipline --
    #[test]
    fn shell_marker_anchored() {
        let rx = m("^__GSD_SHELL_OK__\r?$");
        assert!(rx.is_match(b"noise\r\n__GSD_SHELL_OK__\r\nterm% "));
        assert!(rx.is_match(b"__GSD_SHELL_OK__"));
        assert!(rx.is_match(b"__GSD_SHELL_OK__\n"));
    }
    #[test]
    fn shell_marker_rejects_echo_attack() {
        // WR-04: the echoed probe command line must never satisfy the proof.
        let rx = m("^__GSD_SHELL_OK__\r?$");
        assert!(!rx.is_match(b"term% echo __GSD_SHELL_^OK__\r\n"));
        assert!(!rx.is_match(b"echo __GSD_SHELL_^OK__\r\n"));
        assert!(!rx.is_match(b"__GSD_SHELL_OK__ trailing\r\n"));
        assert!(!rx.is_match(b"x__GSD_SHELL_OK__\r\n"));
    }

    // ---- PROMPT_RE: '^term% $' ---------------------------------------------
    #[test]
    fn prompt_anchored() {
        let rx = m("^term% $");
        assert!(rx.is_match(b"__GSD_SHELL_OK__\r\nterm% \r\n"));
    }
    #[test]
    fn prompt_rejects_assignment_echo() {
        // the echoed assignment line contains 'term% ' as a substring but
        // must never match the anchored bare-prompt proof
        let rx = m("^term% $");
        assert!(!rx.is_match(b"prompt='term% '\r\n"));
        assert!(!rx.is_match(b" term% \r\n")); // leading space breaks ^
    }

    // ---- marker/status anchors ----------------------------------------------
    #[test]
    fn exit_and_promptset_markers() {
        let st = m("^__GSD_EXIT__\r?$");
        assert!(st.is_match(b"term% echo __GSD_EXIT__$status\r\n__GSD_EXIT__\r\n"));
        assert!(!st.is_match(b"__GSD_EXIT__0\r\n"));
        let ps = m("^__GSD_PROMPT_SET__\r?$");
        assert!(ps.is_match(b"echo __GSD_PROMPT_SET__\r\n__GSD_PROMPT_SET__\r\n"));
        assert!(!ps.is_match(b"echo __GSD_PROMPT_SET__\r\n"));
    }

    // ---- wc count row: '^ *2\r?$' --------------------------------------------
    #[test]
    fn wc_count_row() {
        let rx = m("^ *2\r?$");
        assert!(rx.is_match(b"term% hcat x | hwc -l\r\n   2\r\n"));
        assert!(rx.is_match(b"\n2\r\n"));
        assert!(!rx.is_match(b"\n   3\r\n"));
        assert!(!rx.is_match(b"\n  20\r\n")); // trailing digit
    }

    // ---- date line: '(UTC|GMT) 20[0-9][0-9]\r?$' ------------------------------
    #[test]
    fn date_line() {
        let rx = m("(UTC|GMT) 20[0-9][0-9]\r?$");
        assert!(rx.is_match(b"term% /boot/hdate\r\nTue Nov  3 17:00:00 UTC 2026\r\n"));
        assert!(rx.is_match(b"GMT 2099\n"));
        assert!(!rx.is_match(b"UTC 1999\n"));
        assert!(!rx.is_match(b"UTC 2026x\n"));
        assert!(!rx.is_match(b"PDT 2026\n"));
    }

    // ---- ps rows: '\src\r?$' and '\bhfactotum\b' -------------------------------
    #[test]
    fn ps_rc_row() {
        let rx = m("\\src\r?$");
        assert!(rx.is_match(b"glenda         123    0:00   0:00  1234K Pread   rc\r\n"));
        assert!(!rx.is_match(b"rcinit\r\n"));
        assert!(!rx.is_match(b"myrc\r\n"));
    }
    #[test]
    fn ps_factotum_word_boundary() {
        let rx = m("\\bhfactotum\\b");
        assert!(rx.is_match(b"glenda         456    0:00   0:00  987K Pread   hfactotum\r\n"));
        assert!(!rx.is_match(b"xhfactotum"));
        assert!(!rx.is_match(b"hfactotumx"));
    }

    // ---- 'usage: .*hipconfig' — dot does not cross newline ----------------------
    #[test]
    fn usage_dot_star() {
        let rx = m("usage: .*hipconfig");
        assert!(rx.is_match(b"usage: hipconfig [-abc] ...\n"));
        assert!(rx.is_match(b"usage:  /boot/hipconfig blah\n"));
        assert!(!rx.is_match(b"usage:\nhipconfig")); // '.' excludes \n
        assert!(!rx.is_match(b"usage: ipconfig\n"));
    }

    // ---- ENTRY-line shape (trace-syscalls parser) --------------------------------
    // '^(\d+) (\S+) (\S+) [0-9a-f]+(?:\s|$)' — pc as BARE hex, possibly the
    // last field (end-of-line case); return fragments beginning ' = ' never match
    #[test]
    fn entry_line_shape() {
        let rx = m("^(\\d+) (\\S+) (\\S+) [0-9a-f]+(?:\\s|$)");
        let t = b"196 tracehello Pwrite 14918 1  0x7fffefd38/\"hello\" 21 -1";
        let mm = rx.find(t).expect("entry line matches");
        assert_eq!(mm.group_str(1, t), Some("196"));
        assert_eq!(mm.group_str(2, t), Some("tracehello"));
        assert_eq!(mm.group_str(3, t), Some("Pwrite"));
        // pc at end of line (no trailing arg)
        let t2 = b"196 tracehello Exits 14b6c";
        assert!(rx.is_match(t2));
        // return fragments never match
        assert!(!rx.is_match(b" = 21 \"\" 32218768000 32218838000"));
        // pc must be bare hex (no 0x prefix)
        assert!(!rx.is_match(b"196 tracehello Pwrite 0x14918 1"));
    }

    // ---- capture groups: arm markers, frag tags, sweep brackets -------------------
    #[test]
    fn capture_groups() {
        let arm = m("__GSD_ARM_(boot|paqfs|srv|rc)_(\\d+)__");
        let t = b"__GSD_ARM_paqfs_1259__\n";
        let mm = arm.find(t).expect("arm marker matches");
        assert_eq!(mm.group_str(1, t), Some("paqfs"));
        assert_eq!(mm.group_str(2, t), Some("1259"));

        let pid = m("__GSD_PID__(\\d+)");
        let t = b"echo __GSD_PID__$apid\r\n__GSD_PID__234\r\n";
        let mm = pid.find(t).expect("pid marker");
        assert_eq!(mm.group_str(1, t), Some("234"));

        let sw = m("__GSD_SWEEP_(BEGIN|DONE)_(\\w+)__");
        let t = b"__GSD_SWEEP_BEGIN_ourstacksmoke__\n";
        let mm = sw.find(t).expect("sweep bracket");
        assert_eq!(mm.group_str(1, t), Some("BEGIN"));
        assert_eq!(mm.group_str(2, t), Some("ourstacksmoke"));
    }

    // ---- frag tag: '__GSD_FRAG_(\d+)__(.*)' — (.*) stops at newline ----------------
    #[test]
    fn frag_tag_capture() {
        let rx = m("__GSD_FRAG_(\\d+)__(.*)");
        let t = b"__GSD_FRAG_234__234 rc Create 265b0 0x34900\n__GSD_FRAG_234__ = 5\n";
        let mm = rx.find(t).expect("frag tag");
        assert_eq!(mm.group_str(1, t), Some("234"));
        assert_eq!(mm.group_str(2, t), Some("234 rc Create 265b0 0x34900"));
    }

    // ---- find_at (search_from) honours the base offset ------------------------------
    #[test]
    fn find_at_respects_base() {
        let rx = m("^term% $");
        let t = b"term% \njunk\nterm% \n";
        let first = rx.find(t).unwrap();
        assert_eq!(first.span.start, 0);
        let second = rx.find_at(t, first.span.end).unwrap();
        assert_eq!(second.span.start, 10);
        assert!(rx.find_at(t, second.span.end).is_none());
    }

    // ---- escape_lit (drive9 --steps default echo pattern) ---------------------------
    #[test]
    fn escape_lit_metachars() {
        assert_eq!(escape_lit(b"/boot/hello\r"), "\\/boot\\/hello\\\r");
        assert_eq!(escape_lit(b"echo __GSD_EXIT__"), "echo\\ __GSD_EXIT__");
        assert_eq!(escape_lit(b"X=`{/boot/hecho h"), "\\X\\=\\`\\{\\/boot\\/hecho\\ h");
        // an escaped pattern matches the literal bytes
        let lit = &b"/boot/hls /tmp/su"[..];
        let rx = m(&escape_lit(lit));
        assert!(rx.is_match(b"term% /boot/hls /tmp/subset\r\n"));
        assert!(!rx.is_match(b"term% XbootXhls /tmp/su\r\n"));
    }

    // ---- compile errors --------------------------------------------------------------
    #[test]
    fn invalid_patterns_error() {
        assert!(Regex::new("(").is_err());
        assert!(Regex::new(")").is_err());
        assert!(Regex::new("[").is_err());
        assert!(Regex::new("a**").is_err());
        assert!(Regex::new("\\").is_err());
    }

    // ---- literal patterns used by trace markers ---------------------------------------
    #[test]
    fn literal_markers() {
        assert!(m("paqfs\\.\\.\\.").is_match(b"paqfs... on #s/boot"));
        assert!(!m("paqfs\\.\\.\\.").is_match(b"paqfsX.."));
        assert!(m("init: starting /bin/rc").is_match(b"init: starting /bin/rc\n"));
        assert!(m("stacksmoke: depth 64 ok").is_match(b"stacksmoke: depth 64 ok\r\n"));
        assert!(m("__GSD_LOOP_DONE_boot__").is_match(b"__GSD_LOOP_DONE_boot__\n"));
    }
}
