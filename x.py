#! /usr/bin/env python3

import os
import shutil
import argparse

parser = argparse.ArgumentParser("build_boot", "buiding a bootloader")
parser.add_argument("-c", "--clear", action="store_true")
parser.add_argument("-t", "--test", action="store_true")
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

CURRENT_DIR = os.getcwd() + "/"
X_SCRIPT_LOCATION = os.path.dirname(os.path.realpath(__file__)) + "/"

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
    execute(
        "", "remove target folder", lambda: shutil.rmtree(X_SCRIPT_LOCATION + "target")
    )
    execute(
        "", "remove isofiles folder", lambda: shutil.rmtree(CURRENT_DIR + "isofiles")
    )
    execute("", "remove binary", lambda: os.remove(X_SCRIPT_LOCATION + "axiom_os"))
    execute("", "remove iso", lambda: os.remove(CURRENT_DIR + ISO_NAME))

elif args.check:
    execute(
        " ".join(
            [
                "grub-file",
                "--is-x86-multiboot2",
                X_SCRIPT_LOCATION + "axiom_os",
            ]
        )
    )

elif args.makeiso:
    execute(" ".join(["mkdir", "-p", CURRENT_DIR + "isofiles/boot/grub"]))
    execute(
        " ".join(
            [
                "mv",
                X_SCRIPT_LOCATION + "axiom_os",
                CURRENT_DIR + "isofiles/boot/bootloader",
            ]
        )
    )
    with open(CURRENT_DIR + "isofiles/boot/grub/grub.cfg", "w") as f:
        f.write(GRUB_CFG_FILECONTENT)
    execute(
        " ".join(
            ["grub-mkrescue", "-o", CURRENT_DIR + ISO_NAME, CURRENT_DIR + "isofiles"]
        )
    )

elif args.runqemu:
    execute(" ".join(["qemu-system-x86_64", "-cdrom", CURRENT_DIR + ISO_NAME]))

elif args.test:
    execute("cargo b --tests")

else:
    execute("cargo b")
