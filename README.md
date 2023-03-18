# AxiomOS
Some toy project to making an OS. Basic setup is introduced in this [website](https://littleosbook.github.io/)
and this [website](https://os.phil-opp.com/edition-1/).

## Prerequisties
You need these programs, first of all:
- qemu
- grub
- gcc
- x86_64-elf-gcc

## How to run this operating system
First you need to bootstrap the build system with this command:
```console
gcc cb.c -o cb
```

You can see all suubcommands by running
```console
./cb
```

Run this command in the shell to compile assembly programs and C programs
```console
./cb compile
```

If you want to make iso file and run qemu, run
```console
./cb make-iso && ./cb run-qemu
```
