use std::env;
use std::path::PathBuf;

fn main() {
    let linker_script_dir =
        PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap()).join("linker.ld");

    println!("cargo:rustc-link-arg-bins=-n");
    println!(
        "cargo:rustc-link-arg-bins=--script={}",
        linker_script_dir.display()
    );
}
