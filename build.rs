use std::env;
use std::path::PathBuf;

fn main() {
    let manifest_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());
    let linker_script_dir = manifest_dir.join("linker.ld");
    let output_bin = manifest_dir.join("axiom_os");

    println!("cargo:rustc-link-arg-bins=-n");
    println!(
        "cargo:rustc-link-arg-bins=--script={}",
        linker_script_dir.display()
    );
    println!("cargo:rustc-link-arg-bins=-o{}", output_bin.display());
}
