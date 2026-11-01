# AxiomOS in Glosso

`../AxiomOS`는 x86-64 Multiboot2 OS입니다.
GRUB의 BIOS 부팅 경로를 사용하며, VGA 텍스트 화면에 `Hello, AxiomOS!`와
0부터 9999까지의 숫자 및 다음 숫자를 출력합니다. 원본 MIT 라이선스를 유지합니다.

## 빌드와 실행

Linux 호스트에서 수정된 Glosso 컴파일러, GRUB의 `i386-pc` 모듈과
`grub-mkrescue`, xorriso, QEMU가 필요합니다.
기본 `fasm` 부트 경로에는 fasm이 필요하고, `inline` 경로에는 필요하지 않습니다.
Zig와 외부 `ld`/`ld.lld`는 사용하지 않습니다. Glosso는 내장 LLD를 포함한 빌드를 사용하세요.

먼저 이 변경을 포함한 Glosso를 빌드합니다.

```sh
cd ../glosso
./build.exe build
cd ../AxiomOS-glosso
```

NixOS에서는 이 디렉터리에서 `nix-shell`로 도구 환경에 들어갈 수 있습니다.
아래 명령은 모두 **AxiomOS-glosso 디렉터리 안에서** 실행합니다.

```sh
# 커널 ELF만 생성: build/kernel.bin
../glosso/build/bin/glosso --std ../glosso/std first.glo

# 커널을 빌드하고 부팅 ISO 생성: AxiomOS.iso
../glosso/build/bin/glosso --std ../glosso/std first.glo -- make-iso

# 빌드 → ISO → QEMU 창에서 부팅
../glosso/build/bin/glosso --std ../glosso/std first.glo -- run-qemu

# Glosso inline assembly로 부팅: build/inline/kernel.bin, AxiomOS-inline.iso
../glosso/build/bin/glosso --std ../glosso/std first.glo -- run-qemu inline
```

설치된 `glosso`와 표준 라이브러리가 이 변경을 포함하면 `glosso first.glo`로도
실행할 수 있습니다. 기존 설치본에는 `linker_script`나 `--no-std`가 없을 수 있으므로
위 예시는 저장소에서 빌드한 컴파일러와 표준 라이브러리를 명시합니다.

명령 뒤에 `fasm` 또는 `inline`을 붙여 부트 구현을 고릅니다. 생략하면 기존처럼
`fasm`을 사용합니다. fasm 산출물은 `build/`와 `AxiomOS.iso`에, inline 산출물은
`build/inline/`과 `AxiomOS-inline.iso`에 따로 저장합니다.

| `first.glo --` 뒤의 명령 | 동작 |
|---|---|
| `build` 또는 생략 | 선택한 부트 오브젝트와 Glosso 커널을 빌드·링크 |
| `make-iso` | 빌드 후 GRUB ISO 생성 |
| `make-test-iso` | Glosso VGA 테스트가 포함된 별도 커널·ISO 생성 |
| `run-qemu` | ISO 생성 후 QEMU 실행, 선택한 출력 디렉터리의 `debug.log`에 출력 복제 |
| `clean` | 전체 빌드 산출물 제거; `clean inline`은 inline 산출물만 제거 |
| `help` | 명령 목록 표시 |

`FASM`, `GRUB_MKRESCUE`, `QEMU` 환경 변수로 각 도구의 실행 파일을
지정할 수 있습니다. 파일 경로에 공백이 있어도 하나의 인자로 전달합니다.
