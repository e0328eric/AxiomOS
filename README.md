# AxiomOS
Some toy project to making an OS. Basic setup is introduced in this [website](https://littleosbook.github.io/)

## Prerequisties
You need these programs, first of all:
- qemu
- grub
- gcc
- i686-elf-gcc

## How to run this operating system
Run this command in the shell
```console
gcc cb.c -o cb && ./cb compile
```

If you want to see unit test case result, run this command in the shell
```console
gcc cb.c -o cb && ./cb make-iso && ./cb run-qemu
```
