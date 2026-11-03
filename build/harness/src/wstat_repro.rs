// scratch test of the REAL donor Twstat byte shape against srv9
#[cfg(test)]
mod repro {
    use crate::srv9::*;
    use std::fs;
    use std::io::{Read, Write};
    use std::net::{TcpListener, TcpStream};
    use std::thread;
    use std::time::Duration;

    fn send_frame(s: &TcpStream, tag: &mut u16, ty: u8, payload: &[u8]) -> (u8, Vec<u8>) {
        *tag += 1;
        let mut out = Vec::new();
        out.extend_from_slice(&p32(4 + 1 + 2 + payload.len() as u32));
        out.push(ty);
        out.extend_from_slice(&p16(*tag));
        out.extend_from_slice(payload);
        (&*s).write_all(&out).unwrap();
        let mut hdr = [0u8; 4];
        (&*s).read_exact(&mut hdr).unwrap();
        let size = u32::from_le_bytes(hdr) as usize;
        let mut rest = vec![0u8; size - 4];
        (&*s).read_exact(&mut rest).unwrap();
        (rest[0], rest[3..].to_vec())
    }

    #[test]
    fn real_nulldir_wstat_rename() {
        let dir = std::env::temp_dir().join(format!("wstatrepro.{}", std::process::id()));
        let root = dir.join("root");
        fs::create_dir_all(root.join("tmp/subset")).unwrap();
        fs::write(root.join("tmp/subset/copied"), b"data\n").unwrap();
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let addr = listener.local_addr().unwrap();
        let r = root.clone();
        thread::spawn(move || {
            let _ = serve(listener, &r, &["/tmp".to_string()]);
        });
        std::thread::sleep(Duration::from_millis(100));
        let s = TcpStream::connect(addr).unwrap();
        let mut tag = 0u16;
        // version + attach
        let mut p = Vec::new();
        p.extend_from_slice(&p32(MAXMSIZE));
        p.extend_from_slice(&pstr(b"9P2000"));
        send_frame(&s, &mut tag, TVERSION, &p);
        let mut p = Vec::new();
        p.extend_from_slice(&p32(1));
        p.extend_from_slice(&p32(0xFFFFFFFF));
        p.extend_from_slice(&pstr(b"glenda"));
        p.extend_from_slice(&pstr(b""));
        send_frame(&s, &mut tag, TATTACH, &p);
        // walk to tmp/subset/copied on fid 2
        let mut p = Vec::new();
        p.extend_from_slice(&p32(1));
        p.extend_from_slice(&p32(2));
        p.extend_from_slice(&p16(3));
        for n in ["tmp", "subset", "copied"] {
            p.extend_from_slice(&pstr(n.as_bytes()));
        }
        let (t, _) = send_frame(&s, &mut tag, TWALK, &p);
        assert_eq!(t, RWALK);
        // Twstat with the REAL nulldir shape: the stat buffer carries TWO
        // size prefixes (stat[n] + the Dir's own u16 length), then the
        // 0xFF-filled fixed body + name + three empty trailing strings
        let mut dbody = vec![0xFFu8; 39];
        dbody.extend_from_slice(&pstr(b"moved"));
        dbody.extend_from_slice(&pstr(b""));
        dbody.extend_from_slice(&pstr(b""));
        dbody.extend_from_slice(&pstr(b""));
        let mut stat = Vec::new();
        stat.extend_from_slice(&p16(dbody.len() as u16));
        stat.extend_from_slice(&dbody);
        let mut p = Vec::new();
        p.extend_from_slice(&p32(2));
        p.extend_from_slice(&p16(stat.len() as u16));
        p.extend_from_slice(&stat);
        let (t, rpayload) = send_frame(&s, &mut tag, TWSTAT, &p);
        eprintln!("Twstat reply type {} payload {:?}", t, rpayload);
        assert_eq!(t, RWSTAT);
        assert!(root.join("tmp/subset/moved").exists(), "rename happened");
        assert!(!root.join("tmp/subset/copied").exists());
        let _ = fs::remove_dir_all(&dir);
    }
}
