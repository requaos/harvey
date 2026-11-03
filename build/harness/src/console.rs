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
