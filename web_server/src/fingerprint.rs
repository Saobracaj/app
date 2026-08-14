//! Content fingerprints for the files in the bundle.
//!
//! Flutter's web output is not content-hashed — `main.dart.js` and
//! `assets/assets/allQuestions.json` keep their names across releases — so a
//! browser has no way of telling last week's copy from today's by its URL. The
//! server therefore asks every client to revalidate (`Cache-Control: no-cache`)
//! and answers that revalidation from a fingerprint taken at startup: a file
//! whose bytes are unchanged gets a 304 costing a few hundred bytes, and a file
//! a deploy touched gets sent again immediately. No release waits out a TTL.
//!
//! The fingerprint is a plain non-cryptographic hash of the bytes: it only has
//! to change when the file changes, and nothing here is a security boundary.

use std::collections::HashMap;
use std::io::Read;
use std::path::Path;

/// URL path (`/main.dart.js`) → entity tag for the file currently on disk.
pub struct Fingerprints {
    by_path: HashMap<String, String>,
}

impl Fingerprints {
    /// Hashes every file under `root`, once, at startup.
    ///
    /// An unreadable file is skipped rather than fatal: it simply gets no
    /// entity tag, which costs a revalidation and never a wrong answer.
    pub fn scan(root: &Path) -> Self {
        let mut by_path = HashMap::new();
        collect(root, root, &mut by_path);
        Self { by_path }
    }

    /// The `ETag` value for a request path, if that path is a bundled file.
    ///
    /// Weak (`W/`), because the compression layer re-encodes the body while
    /// leaving the content it represents identical.
    pub fn etag(&self, path: &str) -> Option<&str> {
        self.by_path.get(path).map(String::as_str)
    }

    pub fn len(&self) -> usize {
        self.by_path.len()
    }
}

fn collect(root: &Path, dir: &Path, out: &mut HashMap<String, String>) {
    let Ok(entries) = std::fs::read_dir(dir) else {
        return;
    };
    for entry in entries.flatten() {
        let path = entry.path();
        match entry.file_type() {
            Ok(kind) if kind.is_dir() => collect(root, &path, out),
            Ok(kind) if kind.is_file() => {
                let (Ok(relative), Some(hash)) = (path.strip_prefix(root), hash_file(&path)) else {
                    continue;
                };
                let Some(relative) = relative.to_str() else {
                    continue;
                };
                out.insert(format!("/{relative}"), format!("W/\"{hash:016x}\""));
            }
            _ => {}
        }
    }
}

/// FNV-1a over the file's bytes, read in chunks so a 40 MB `canvaskit` blob
/// never sits in memory whole.
fn hash_file(path: &Path) -> Option<u64> {
    const OFFSET_BASIS: u64 = 0xcbf2_9ce4_8422_2325;
    const PRIME: u64 = 0x0000_0100_0000_01b3;

    let mut file = std::fs::File::open(path).ok()?;
    let mut buffer = vec![0_u8; 64 * 1024];
    let mut hash = OFFSET_BASIS;
    loop {
        let read = file.read(&mut buffer).ok()?;
        if read == 0 {
            return Some(hash);
        }
        for byte in &buffer[..read] {
            hash ^= u64::from(*byte);
            hash = hash.wrapping_mul(PRIME);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn every_file_in_the_tree_gets_a_tag_that_follows_its_contents() {
        let dir = tempfile::tempdir().unwrap();
        std::fs::write(dir.path().join("main.dart.js"), "// v1").unwrap();
        std::fs::create_dir(dir.path().join("canvaskit")).unwrap();
        std::fs::write(dir.path().join("canvaskit/skwasm.wasm"), "\0asm").unwrap();

        let first = Fingerprints::scan(dir.path());
        assert_eq!(first.len(), 2);
        let entry = first.etag("/main.dart.js").unwrap().to_string();
        assert!(entry.starts_with("W/\""));
        assert!(first.etag("/canvaskit/skwasm.wasm").is_some());
        assert!(first.etag("/nope.js").is_none());

        // A release that changes one file changes that file's tag alone.
        std::fs::write(dir.path().join("main.dart.js"), "// v2").unwrap();
        let second = Fingerprints::scan(dir.path());
        assert_ne!(second.etag("/main.dart.js").unwrap(), entry);
        assert_eq!(
            second.etag("/canvaskit/skwasm.wasm"),
            first.etag("/canvaskit/skwasm.wasm"),
        );
    }

    #[test]
    fn a_missing_root_is_an_empty_index_rather_than_a_panic() {
        assert_eq!(Fingerprints::scan(Path::new("/nonexistent/bundle")).len(), 0);
    }
}
