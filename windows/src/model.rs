//! The Parakeet TDT 0.6B v3 model (int8 ONNX, about 670 MB), downloaded once
//! from Hugging Face and checked against pinned SHA-256 hashes.

use sha2::{Digest, Sha256};
use std::fs::{self, File};
use std::io::{self, BufReader, Read, Write};
use std::path::{Path, PathBuf};

pub const MODEL_NAME: &str = "parakeet-tdt-0.6b-v3-int8";
const REPO: &str = "istupakov/parakeet-tdt-0.6b-v3-onnx";
/// Pinned revision, so a change upstream cannot swap the files under us.
const REVISION: &str = "8f23f0c03c8761650bdb5b40aaf3e40d2c15f1ce";

pub struct ModelFile {
    pub name: &'static str,
    pub size: u64,
    pub sha256: &'static str,
}

pub const FILES: &[ModelFile] = &[
    ModelFile {
        name: "encoder-model.int8.onnx",
        size: 652_183_999,
        sha256: "6139d2fa7e1b086097b277c7149725edbab89cc7c7ae64b23c741be4055aff09",
    },
    ModelFile {
        name: "decoder_joint-model.int8.onnx",
        size: 18_202_004,
        sha256: "eea7483ee3d1a30375daedc8ed83e3960c91b098812127a0d99d1c8977667a70",
    },
    ModelFile {
        name: "nemo128.onnx",
        size: 139_764,
        sha256: "a9fde1486ebfcc08f328d75ad4610c67835fea58c73ba57e3209a6f6cf019e9f",
    },
    ModelFile {
        name: "vocab.txt",
        size: 93_939,
        sha256: "d58544679ea4bc6ac563d1f545eb7d474bd6cfa467f0a6e2c1dc1c7d37e3c35d",
    },
];

pub fn total_size() -> u64 {
    FILES.iter().map(|f| f.size).sum()
}

pub fn model_dir(models_dir: &Path) -> PathBuf {
    models_dir.join(MODEL_NAME)
}

/// Every file present with the expected size. Hashes are checked on download.
pub fn is_installed(dir: &Path) -> bool {
    FILES.iter().all(|f| fs::metadata(dir.join(f.name)).map(|m| m.len() == f.size).unwrap_or(false))
}

pub fn url(file: &ModelFile) -> String {
    format!("https://huggingface.co/{REPO}/resolve/{REVISION}/{}", file.name)
}

/// Downloads missing files into `dir`, reporting `(downloaded, total)` bytes.
/// Each file goes to a `.part` file first and is renamed only after its hash matches.
pub fn download(dir: &Path, mut progress: impl FnMut(u64, u64)) -> Result<(), String> {
    fs::create_dir_all(dir).map_err(|e| format!("Cannot create {}: {e}", dir.display()))?;
    let total = total_size();
    let mut done = 0u64;
    for file in FILES {
        let target = dir.join(file.name);
        if fs::metadata(&target).map(|m| m.len() == file.size).unwrap_or(false) {
            done += file.size;
            progress(done, total);
            continue;
        }
        let part = dir.join(format!("{}.part", file.name));
        let response = ureq::get(&url(file))
            .call()
            .map_err(|e| format!("Download of {} failed: {e}", file.name))?;
        let mut reader = response.into_reader();
        let mut out = File::create(&part).map_err(|e| format!("Cannot write {}: {e}", part.display()))?;
        let mut hasher = Sha256::new();
        let mut buf = vec![0u8; 1 << 16];
        let mut written = 0u64;
        let mut last_report = 0u64;
        loop {
            let n = reader.read(&mut buf).map_err(|e| format!("Download of {} broke off: {e}", file.name))?;
            if n == 0 {
                break;
            }
            out.write_all(&buf[..n]).map_err(|e| format!("Cannot write {}: {e}", part.display()))?;
            hasher.update(&buf[..n]);
            written += n as u64;
            if written - last_report > 4 << 20 {
                last_report = written;
                progress(done + written, total);
            }
        }
        out.flush().map_err(|e| e.to_string())?;
        drop(out);
        let digest = hex(&hasher.finalize());
        if written != file.size || digest != file.sha256 {
            let _ = fs::remove_file(&part);
            return Err(format!(
                "{} is damaged (got {written} bytes, sha256 {digest}). Try again.",
                file.name
            ));
        }
        fs::rename(&part, &target).map_err(|e| format!("Cannot save {}: {e}", target.display()))?;
        done += file.size;
        progress(done, total);
    }
    Ok(())
}

/// Recomputes every hash; slow (reads 670 MB), used by `warble verify-model`.
pub fn verify(dir: &Path) -> Result<(), String> {
    for file in FILES {
        let path = dir.join(file.name);
        let digest = sha256_file(&path).map_err(|e| format!("{}: {e}", path.display()))?;
        if digest != file.sha256 {
            return Err(format!("{} does not match the expected hash", file.name));
        }
    }
    Ok(())
}

fn sha256_file(path: &Path) -> io::Result<String> {
    let mut reader = BufReader::new(File::open(path)?);
    let mut hasher = Sha256::new();
    io::copy(&mut reader, &mut hasher)?;
    Ok(hex(&hasher.finalize()))
}

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn urls_are_pinned_to_a_revision() {
        assert!(url(&FILES[0]).contains(REVISION));
        assert_eq!(total_size(), 670_619_706);
    }

    #[test]
    fn partial_install_is_not_installed() {
        let dir = std::env::temp_dir().join(format!("warble-model-{}", uuid::Uuid::new_v4()));
        fs::create_dir_all(&dir).unwrap();
        fs::write(dir.join("vocab.txt"), b"x").unwrap();
        assert!(!is_installed(&dir));
    }
}
