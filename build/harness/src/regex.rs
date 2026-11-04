//! regex.rs — std-only byte-oriented backtracking regex engine (no new
//! crates). Covers exactly the pattern families the harness drivers
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
//! Matching runs on bounded buffers with a GLOBAL step cap
//! per search (2M steps); a pathological pattern returns no-match instead of
//! hanging.

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

#[derive(Clone, Debug)]
enum Node {
    Empty,
    Char(u8),
    Any, // '.' — any byte except \n (Python default)
    Class { neg: bool, ranges: Vec<(u8, u8)> },
    Start, // ^ (multiline)
    End,   // $ (multiline)
    WordB,
    NotWordB,
    Group(usize, Box<Node>),
    Cat(Vec<Node>),
    Alt(Vec<Node>),
    Rep {
        child: Box<Node>,
        min: u32,
        max: Option<u32>,
    },
}

#[derive(Debug)]
pub struct Regex {
    root: Node,
    ncap: usize,
    ci: bool,
}

const MAX_STEPS: usize = 2_000_000;

/// Continuation: given a position (and the capture table), match the rest of
/// the pattern; Some(end) on success. CPS is what lets a greedy repeat
/// INSIDE a group yield shorter spans when the outer sequence fails.
type Cont<'a> = &'a dyn Fn(usize, &mut Vec<Option<Span>>) -> Option<usize>;

struct Ctx<'t> {
    text: &'t [u8],
    ci: bool,
    steps: std::cell::Cell<usize>,
}

impl<'t> Ctx<'t> {
    fn bump(&self) -> bool {
        let n = self.steps.get() + 1;
        self.steps.set(n);
        n <= MAX_STEPS
    }
    fn lc(&self, b: u8) -> u8 {
        if self.ci {
            b.to_ascii_lowercase()
        } else {
            b
        }
    }
    fn is_word(&self, pos: usize) -> bool {
        pos < self.text.len() && {
            let b = self.text[pos];
            b.is_ascii_alphanumeric() || b == b'_'
        }
    }
    fn in_class(&self, b: u8, ranges: &[(u8, u8)], neg: bool) -> bool {
        let b = self.lc(b);
        let inside = ranges.iter().any(|&(lo, hi)| b >= lo && b <= hi);
        inside != neg
    }

    /// Match `nodes` then the continuation.
    fn m_seq(&self, nodes: &[Node], pos: usize, caps: &mut Vec<Option<Span>>, k: Cont) -> Option<usize> {
        if nodes.is_empty() {
            return k(pos, caps);
        }
        if !self.bump() {
            return None;
        }
        self.m_one(&nodes[0], pos, caps, &|p, c| self.m_seq(&nodes[1..], p, c, k))
    }

    fn m_one(&self, n: &Node, pos: usize, caps: &mut Vec<Option<Span>>, k: Cont) -> Option<usize> {
        if !self.bump() {
            return None;
        }
        match n {
            Node::Empty => k(pos, caps),
            Node::Char(c) => {
                if pos < self.text.len() && self.lc(*c) == self.lc(self.text[pos]) {
                    k(pos + 1, caps)
                } else {
                    None
                }
            }
            Node::Any => {
                if pos < self.text.len() && self.text[pos] != b'\n' {
                    k(pos + 1, caps)
                } else {
                    None
                }
            }
            Node::Class { neg, ranges } => {
                if pos < self.text.len() && self.in_class(self.text[pos], ranges, *neg) {
                    k(pos + 1, caps)
                } else {
                    None
                }
            }
            Node::Start => {
                if pos == 0 || self.text[pos - 1] == b'\n' {
                    k(pos, caps)
                } else {
                    None
                }
            }
            Node::End => {
                if pos == self.text.len() || self.text[pos] == b'\n' {
                    k(pos, caps)
                } else {
                    None
                }
            }
            Node::WordB => {
                let before = pos > 0 && self.is_word(pos - 1);
                let here = self.is_word(pos);
                if before != here {
                    k(pos, caps)
                } else {
                    None
                }
            }
            Node::NotWordB => {
                let before = pos > 0 && self.is_word(pos - 1);
                let here = self.is_word(pos);
                if before == here {
                    k(pos, caps)
                } else {
                    None
                }
            }
            Node::Group(idx, child) => {
                let idx = *idx;
                let start = pos;
                self.m_one(child, pos, caps, &|end, caps| {
                    let save = caps[idx];
                    caps[idx] = Some(Span { start, end });
                    match k(end, caps) {
                        Some(e) => Some(e),
                        None => {
                            caps[idx] = save;
                            None
                        }
                    }
                })
            }
            Node::Cat(nodes) => self.m_seq(nodes, pos, caps, k),
            Node::Alt(branches) => {
                for b in branches {
                    if let Some(e) = self.m_one(b, pos, caps, k) {
                        return Some(e);
                    }
                }
                None
            }
            Node::Rep { child, min, max } => self.m_rep(child, 0, *min, *max, pos, caps, k),
        }
    }

    /// Greedy repeat with continuation backtracking: try to extend (one more
    /// rep, then recurse); on failure fall back to the continuation once
    /// `min` is satisfied.
    fn m_rep(
        &self,
        child: &Node,
        count: u32,
        min: u32,
        max: Option<u32>,
        pos: usize,
        caps: &mut Vec<Option<Span>>,
        k: Cont,
    ) -> Option<usize> {
        if !self.bump() {
            return None;
        }
        if max.map_or(true, |m| count < m) {
            let r = self.m_one(child, pos, caps, &|p2, caps2| {
                // never extend on an empty match (infinite loop guard)
                if p2 == pos {
                    None
                } else {
                    self.m_rep(child, count + 1, min, max, p2, caps2, k)
                }
            });
            if r.is_some() {
                return r;
            }
        }
        if count >= min {
            k(pos, caps)
        } else {
            None
        }
    }
}

struct Parser<'a> {
    b: &'a [u8],
    i: usize,
    ncap: usize,
    ci: bool,
}

impl<'a> Parser<'a> {
    fn peek(&self) -> Option<u8> {
        self.b.get(self.i).copied()
    }
    fn next(&mut self) -> Option<u8> {
        let c = self.peek();
        if c.is_some() {
            self.i += 1;
        }
        c
    }

    fn parse_alt(&mut self) -> Result<Node, String> {
        let mut branches = vec![self.parse_cat()?];
        while self.peek() == Some(b'|') {
            self.i += 1;
            branches.push(self.parse_cat()?);
        }
        Ok(if branches.len() == 1 {
            branches.pop().unwrap()
        } else {
            Node::Alt(branches)
        })
    }

    fn parse_cat(&mut self) -> Result<Node, String> {
        let mut nodes = Vec::new();
        while let Some(c) = self.peek() {
            if c == b'|' || c == b')' {
                break;
            }
            let atom = self.parse_atom()?;
            let atom = self.parse_repeat(atom)?;
            nodes.push(atom);
        }
        Ok(match nodes.len() {
            0 => Node::Empty,
            1 => nodes.pop().unwrap(),
            _ => Node::Cat(nodes),
        })
    }

    fn parse_repeat(&mut self, atom: Node) -> Result<Node, String> {
        let (min, max) = match self.peek() {
            Some(b'*') => (0, None),
            Some(b'+') => (1, None),
            Some(b'?') => (0, Some(1)),
            _ => return Ok(atom),
        };
        self.i += 1;
        match self.peek() {
            Some(b'*') | Some(b'+') | Some(b'?') => {
                return Err("multiple repeat operators".to_string())
            }
            _ => {}
        }
        Ok(Node::Rep {
            child: Box::new(atom),
            min,
            max,
        })
    }

    fn parse_atom(&mut self) -> Result<Node, String> {
        match self.next() {
            None => Err("unexpected end of pattern".to_string()),
            Some(b'(') => {
                let capture = if self.peek() == Some(b'?') {
                    // (?:...) non-capturing
                    self.i += 1;
                    if self.next() != Some(b':') {
                        return Err("unsupported group extension (only (?:...) )".to_string());
                    }
                    false
                } else {
                    true
                };
                let idx = if capture {
                    self.ncap += 1;
                    self.ncap
                } else {
                    0
                };
                let inner = self.parse_alt()?;
                if self.next() != Some(b')') {
                    return Err("unclosed group".to_string());
                }
                if capture {
                    Ok(Node::Group(idx, Box::new(inner)))
                } else {
                    Ok(inner)
                }
            }
            Some(b')') => Err("unmatched )".to_string()),
            Some(b'[') => self.parse_class(),
            Some(b'^') => Ok(Node::Start),
            Some(b'$') => Ok(Node::End),
            Some(b'.') => Ok(Node::Any),
            Some(b'*') | Some(b'+') | Some(b'?') => Err("nothing to repeat".to_string()),
            Some(b'\\') => self.parse_escape(),
            Some(c) => Ok(Node::Char(c)),
        }
    }

    fn parse_escape(&mut self) -> Result<Node, String> {
        match self.next() {
            None => Err("trailing backslash".to_string()),
            Some(b'd') => Ok(class_node(false, &[(b'0', b'9')], self.ci)),
            Some(b'D') => Ok(class_node(true, &[(b'0', b'9')], self.ci)),
            Some(b's') => Ok(class_node(
                false,
                &[(b' ', b' '), (b'\t', b'\n'), (b'\r', b'\r'), (0x0b, 0x0c)],
                self.ci,
            )),
            Some(b'S') => Ok(class_node(
                true,
                &[(b' ', b' '), (b'\t', b'\n'), (b'\r', b'\r'), (0x0b, 0x0c)],
                self.ci,
            )),
            Some(b'w') => Ok(class_node(
                false,
                &[(b'a', b'z'), (b'A', b'Z'), (b'0', b'9'), (b'_', b'_')],
                self.ci,
            )),
            Some(b'W') => Ok(class_node(
                true,
                &[(b'a', b'z'), (b'A', b'Z'), (b'0', b'9'), (b'_', b'_')],
                self.ci,
            )),
            Some(b'b') => Ok(Node::WordB),
            Some(b'B') => Ok(Node::NotWordB),
            Some(b'r') => Ok(Node::Char(b'\r')),
            Some(b'n') => Ok(Node::Char(b'\n')),
            Some(b't') => Ok(Node::Char(b'\t')),
            Some(c) => Ok(Node::Char(c)), // escaped literal (\( \. \$ \\ …)
        }
    }

    fn class_char(&mut self) -> Result<u8, String> {
        match self.next() {
            None => Err("unclosed class".to_string()),
            Some(b'\\') => match self.next() {
                None => Err("trailing backslash in class".to_string()),
                Some(b'r') => Ok(b'\r'),
                Some(b'n') => Ok(b'\n'),
                Some(b't') => Ok(b'\t'),
                Some(c) => Ok(c),
            },
            Some(c) => Ok(c),
        }
    }

    fn parse_class(&mut self) -> Result<Node, String> {
        let mut neg = false;
        if self.peek() == Some(b'^') {
            neg = true;
            self.i += 1;
        }
        let mut ranges: Vec<(u8, u8)> = Vec::new();
        let mut first = true;
        loop {
            match self.peek() {
                None => return Err("unclosed class".to_string()),
                Some(b']') if !first => {
                    self.i += 1;
                    break;
                }
                _ => {}
            }
            first = false;
            let lo = self.class_char()?;
            if self.peek() == Some(b'-') && self.b.get(self.i + 1).copied() != Some(b']')
                && self.b.get(self.i + 1).is_some()
            {
                self.i += 1; // consume '-'
                let hi = self.class_char()?;
                if hi < lo {
                    return Err("reversed range in class".to_string());
                }
                ranges.push((lo, hi));
            } else {
                ranges.push((lo, lo));
            }
        }
        Ok(class_node(neg, &ranges, self.ci))
    }
}

fn class_node(neg: bool, ranges: &[(u8, u8)], ci: bool) -> Node {
    let ranges = if ci {
        ranges
            .iter()
            .map(|&(lo, hi)| (lo.to_ascii_lowercase(), hi.to_ascii_lowercase()))
            .collect()
    } else {
        ranges.to_vec()
    };
    Node::Class { neg, ranges }
}

impl Regex {
    pub fn new(pat: &str) -> Result<Regex, String> {
        Self::compile(pat, false)
    }
    /// Case-insensitive variant (re.I).
    pub fn new_ci(pat: &str) -> Result<Regex, String> {
        Self::compile(pat, true)
    }
    fn compile(pat: &str, ci: bool) -> Result<Regex, String> {
        let mut p = Parser {
            b: pat.as_bytes(),
            i: 0,
            ncap: 0,
            ci,
        };
        let root = p.parse_alt()?;
        if p.i != pat.len() {
            return Err(format!("trailing garbage at offset {}", p.i));
        }
        Ok(Regex {
            root,
            ncap: p.ncap,
            ci,
        })
    }
    pub fn is_match(&self, text: &[u8]) -> bool {
        self.find(text).is_some()
    }
    pub fn is_match_at(&self, text: &[u8], start: usize) -> bool {
        self.find_at(text, start).is_some()
    }
    pub fn find(&self, text: &[u8]) -> Option<Match> {
        self.find_at(text, 0)
    }
    pub fn find_at(&self, text: &[u8], start: usize) -> Option<Match> {
        let ctx = Ctx {
            text,
            ci: self.ci,
            steps: std::cell::Cell::new(0),
        };
        let mut st = start;
        while st <= text.len() {
            let mut caps: Vec<Option<Span>> = vec![None; self.ncap + 1];
            if let Some(end) = ctx.m_one(&self.root, st, &mut caps, &|p, _| Some(p)) {
                caps[0] = Some(Span { start: st, end });
                return Some(Match {
                    span: Span { start: st, end },
                    groups: caps,
                });
            }
            if !ctx.bump() {
                return None; // global step cap
            }
            st += 1;
        }
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

    // ---- SHELL_RE: '^__GSD_SHELL_OK__\r?$' + the echo-attack discipline --
    #[test]
    fn shell_marker_anchored() {
        let rx = m("^__GSD_SHELL_OK__\r?$");
        assert!(rx.is_match(b"noise\r\n__GSD_SHELL_OK__\r\nterm% "));
        assert!(rx.is_match(b"__GSD_SHELL_OK__"));
        assert!(rx.is_match(b"__GSD_SHELL_OK__\n"));
    }
    #[test]
    fn shell_marker_rejects_echo_attack() {
        // The echoed probe command line must never satisfy the proof.
        let rx = m("^__GSD_SHELL_OK__\r?$");
        assert!(!rx.is_match(b"term% echo __GSD_SHELL_^OK__\r\n"));
        assert!(!rx.is_match(b"echo __GSD_SHELL_^OK__\r\n"));
        assert!(!rx.is_match(b"__GSD_SHELL_OK__ trailing\r\n"));
        assert!(!rx.is_match(b"x__GSD_SHELL_OK__\r\n"));
    }

    // ---- PROMPT_RE: '^term% $' ---------------------------------------------
    // Real-world shape: rc prints the prompt WITHOUT a newline and waits, so
    // the bare 'term% ' line sits at the END of the capture buffer when the
    // proof runs ($ matches at end-of-string); 'term% \n' also matches.
    #[test]
    fn prompt_anchored() {
        let rx = m("^term% $");
        assert!(rx.is_match(b"__GSD_SHELL_OK__\r\nterm% "));
        assert!(rx.is_match(b"noise\nterm% \n"));
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
        assert_eq!(second.span.start, 12);
        assert!(rx.find_at(t, second.span.end).is_none());
    }

    // ---- escape_lit (drive9 --steps default echo pattern) ---------------------------
    #[test]
    fn escape_lit_metachars() {
        assert_eq!(escape_lit(b"/boot/hello\r"), "\\/boot\\/hello\\\r");
        assert_eq!(escape_lit(b"echo __GSD_EXIT__"), "echo\\ __GSD_EXIT__");
        assert_eq!(escape_lit(b"X=`{/boot/hecho h"), "X\\=\\`\\{\\/boot\\/hecho\\ h");
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
