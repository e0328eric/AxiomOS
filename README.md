# AxiomOS
Some toy project to making an OS. Basic setup is introduced in this [website](https://littleosbook.github.io/)

## Prerequisties
You need these programs, first of all:
- qemu
- grub
- gcc
- i686-elf-gcc

## How to run this operating system
First you need to bootstrap the build system with this command:
```console
gcc cb.c -o cb
```

Then run this command in the shell
```console
./cb compile
```

If you want to see unit test case result, run this command in the shell
```console
./cb make-iso && ./cb run-qemu
```
