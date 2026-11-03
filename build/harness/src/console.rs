//! console.rs — shared serial-console machinery for drive9 and
//! trace-syscalls: the bounded Log (ring window + file capture), the reader
//! thread, the QMP "cont" handshake, the bootargs/auth/shell/prompt boot
//! drive, paced sends, and echo-verified command delivery.
//!
//! RED-phase stub: the real implementation lands in the GREEN commit.

use std::os::unix::net::UnixStream;
use std::path::Path;
use std::sync::{Arc, Mutex};

/// Bounded capture: every byte goes to the file unbuffered; the searchable
/// ring trims from `window` down to `trim` bytes (drive9: 512KiB/256KiB;
/// trace-syscalls: 256MiB/128MiB — effectively never, so offset bases stay
/// valid).
pub struct Log {
    #[allow(dead_code)]
    inner: Mutex<Inner>,
    #[allow(dead_code)]
    window: usize,
    #[allow(dead_code)]
    trim: usize,
}

struct Inner {
    buf: Vec<u8>,
    file: std::fs::File,
}

impl Log {
    pub fn new(path: &Path, window: usize, trim: usize) -> std::io::Result<Arc<Log>> {
        Ok(Arc::new(Log {
            inner: Mutex::new(Inner {
                buf: Vec::new(),
                file: std::fs::File::create(path)?,
            }),
            window,
            trim,
        }))
    }
    pub fn write(&self, _data: &[u8]) {}
    pub fn tail(&self, _n: usize) -> Vec<u8> {
        Vec::new()
    }
    pub fn search(&self, _rx: &crate::regex::Regex) -> bool {
        false
    }
    pub fn search_from(&self, _rx: &crate::regex::Regex, _base: usize) -> bool {
        false
    }
    pub fn find_from(&self, _rx: &crate::regex::Regex, _base: usize) -> Option<crate::regex::Match> {
        None
    }
    pub fn len(&self) -> usize {
        0
    }
}

pub fn spawn_reader(_stream: UnixStream, _log: Arc<Log>) -> std::thread::JoinHandle<()> {
    std::thread::spawn(|| {})
}

pub fn qmp_cont(_path: &Path) -> std::io::Result<()> {
    Ok(())
}

pub fn paced_send(_s: &UnixStream, _cmd: &[u8]) {}

#[cfg(test)]
mod tests {
    use super::*;

    struct TempDir(std::path::PathBuf);
    impl TempDir {
        fn new(tag: &str) -> TempDir {
            let mut p = std::env::temp_dir();
            p.push(format!(
                "consoletest.{}.{}.{}",
                std::process::id(),
                tag,
                std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap()
                    .as_nanos()
            ));
            std::fs::create_dir_all(&p).unwrap();
            TempDir(p)
        }
    }
    impl Drop for TempDir {
        fn drop(&mut self) {
            let _ = std::fs::remove_dir_all(&self.0);
        }
    }

    #[test]
    fn log_writes_to_file_and_searches_ring() {
        let td = TempDir::new("log");
        let path = td.0.join("cap.log");
        let log = Log::new(&path, 512 * 1024, 256 * 1024).unwrap();
        log.write(b"line one\r\n");
        log.write(b"term% echo hi\r\n");
        assert_eq!(log.len(), 25);
        let rx = crate::regex::Regex::new("^term% ").unwrap();
        assert!(log.search(&rx));
        let tail = log.tail(9);
        assert_eq!(tail, b"echo hi\r\n");
        // the file has every byte even before any trim
        assert_eq!(std::fs::read(&path).unwrap(), b"line one\r\nterm% echo hi\r\n");
    }

    #[test]
    fn log_trims_ring_but_not_file() {
        let td = TempDir::new("trim");
        let path = td.0.join("cap.log");
        let log = Log::new(&path, 1024, 512).unwrap(); // tiny window for the test
        log.write(&vec![b'a'; 700]);
        log.write(&vec![b'b'; 700]); // crosses the 1024 window → trim to 512
        assert_eq!(log.len(), 512, "ring trimmed to the trim size");
        let tail = log.tail(4);
        assert_eq!(tail, b"bbbb");
        let rx = crate::regex::Regex::new("aaaa").unwrap();
        assert!(!log.search(&rx), "old bytes fell out of the ring");
        assert_eq!(std::fs::read(&path).unwrap().len(), 1400, "file keeps everything");
    }

    #[test]
    fn log_search_from_and_find_from_respect_base() {
        let td = TempDir::new("base");
        let path = td.0.join("cap.log");
        let log = Log::new(&path, 512 * 1024, 256 * 1024).unwrap();
        log.write(b"term% first\r\njunk\r\nterm% second\r\n");
        let rx = crate::regex::Regex::new("^term% ").unwrap();
        let base = 14; // after the first prompt line
        assert!(log.search_from(&rx, base));
        let m = log.find_from(&rx, base).unwrap();
        assert_eq!(m.span.start, 19);
        assert!(log.find_from(&rx, m.span.end).is_none());
    }
}
