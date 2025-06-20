use std::{env, fs::File, io::Write, path::PathBuf};
fn main() {
    println!("cargo:rustc-env=TARGET={}", env::var("TARGET").unwrap());
    let out = PathBuf::from(env::var("OUT_DIR").unwrap());
    let ld = out.join("linker.ld");
    let mut f = File::create(&ld).unwrap();
    f.write_all(include_bytes!("linker.ld")).unwrap();
    println!("cargo:rustc-link-search={}", out.display());
    println!("cargo:rerun-if-changed=linker.ld");
}
