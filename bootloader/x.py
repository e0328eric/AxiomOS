#! /usr/bin/env python3

import os
import shutil
import argparse

parser = argparse.ArgumentParser("build_boot", "buiding a bootloader")
parser.add_argument("-c", "--clear", action="store_true")
parser.add_argument("--makeiso", action="store_true")
parser.add_argument("--runqemu", action="store_true")
parser.add_argument("--check", action="store_true")
args = parser.parse_args()

ISO_NAME = "AxiomOS.iso"

GRUB_CFG_FILECONTENT = """
menuentry "AxiomOS" {
    multiboot2 /boot/bootloader
    boot
}"""

##################################################


def changeExtension(filename, new_ext):
    return filename.split(".")[0] + "." + new_ext


def execute(command, msg=None, callback=None):
    info_header = "\x1b[1m\x1b[38:5:45m[INFO]\x1b[0m: "
    if msg is not None:
        print(info_header + msg)
    else:
        print(info_header + command)
    if callback is not None:
        try:
            callback()
        except:
            pass
    else:
        os.system(command)


if args.clear:
    execute("", "remove target folder", lambda: shutil.rmtree("./target"))
    execute("", "remove iso", lambda: os.remove("./AxiomOS.iso"))

elif args.check:
    execute(
        " ".join(
            [
                "grub-file",
                "--is-x86-multiboot2",
                "./target/x86_64-axiom_os/debug/bootloader",
            ]
        )
    )

elif args.makeiso:
    execute(
        " ".join(["mkdir", "-p", "./target/x86_64-axiom_os/debug/isofiles/boot/grub"])
    )
    execute(
        " ".join(
            [
                "mv",
                "./target/x86_64-axiom_os/debug/bootloader",
                "./target/x86_64-axiom_os/debug/isofiles/boot/bootloader",
            ]
        )
    )
    with open("./target/x86_64-axiom_os/debug/isofiles/boot/grub/grub.cfg", "w") as f:
        f.write(GRUB_CFG_FILECONTENT)
    execute(
        " ".join(
            ["grub-mkrescue", "-o", ISO_NAME, "./target/x86_64-axiom_os/debug/isofiles"]
        )
    )

elif args.runqemu:
    execute(" ".join(["qemu-system-x86_64", "-cdrom", ISO_NAME]))

else:
    execute("cargo b")
