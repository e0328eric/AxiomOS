# AxiomOS
Some toy project to making an OS. Basic setup is introduced in this [website](https://os.phil-opp.com/edition-1/).

## Prerequisties
You need these programs, first of all:
- qemu
- cargo
- grub
- python (to run the script)

## How to run this operating system
Run this command in the shell
```console
./x.py && ./x.py --makeiso && ./x.py --runqemu
```

If you want to see unit test case result, run this command in the shell
```console
./x.py -t && ./x.py --makeiso && ./x.py --runqemu
```
