# AxiomOS in Glosso

`../AxiomOS`의 Zig 커널을 Glosso로 옮긴 x86-64 Multiboot2 OS입니다.
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

## 구현

- `first.glo`: 원본 `build.zig`를 대체하는 컴파일 타임 빌드 프로그램.
  `Compiler.Workspace`로 `x86_64-freestanding`, `--no-main`, `-O2`를 선택하고
  `options.set_linker_script("linker.ld")` 및 선택한 `boot.o`를 내장 링커에 전달합니다.
- `src/kernel/kmain.glo`: 인사·숫자 출력·busy wait·정지 루프.
  원본처럼 `main`에서 `vga.writer()`를 얻어 `writer.print("... {} ...", ...)`로
  출력하고 오류를 `?`로 전파합니다. Glosso 표준 formatter가 정수를 스택 버퍼에서
  변환하며, 커널의 이 출력 경로에는 동적 할당과 libc가 필요하지 않습니다.
- `src/kernel/Vga.glo`: `VgaColorCode`, `VgaColor`, `VgaChar`, `Vga`, `VgaWriter`와
  `init`, `clearMonitor`, `writeChar`, `write`, `scroll`, `moveCursor`를 제공합니다.
  원본과 같은 `buffer: [*]volatile VgaChar` 필드를 가지며, 문자 출력·화면 지우기·
  스크롤은 `buffer[i]`에 구조체를 직접 대입합니다. 80×25 VGA, 16색, 하드웨어 커서,
  줄바꿈·캐리지 리턴·탭·백스페이스 처리를 보존합니다.
- `src/kernel/port.glo`: 원본의 `outb`, `inb`, `inw`와 부팅 후 필요한
  `pause`, `cli`, `hlt`를 Glosso의 `#asm`으로 구현합니다.
  VGA 메모리 접근에는 어셈블리 helper를 사용하지 않고 언어의 `volatile`을 사용합니다.
- `src/bootloader/boot.asm`: 기존 fasm 부트 코드이며 그대로 유지합니다.
  Multiboot2 헤더, 32비트 진입점, 페이지 테이블, GDT, 64비트 전환을 담당합니다.
  첫 1 GiB를 identity mapping하고 SSE2 실행 환경을 설정한 뒤 `glo_kmain`을 호출합니다.
- `src/bootloader/boot.glo`: 같은 부팅 절차를 Glosso의 `#asm`으로 구현합니다.
  `.pushsection`으로 헤더·BSS·코드·GDT를 배치하고 `.code32`/`.code64`로 전환합니다.
  `_start`는 별도 `.text.boot` 섹션의 어셈블러 심볼입니다. `boot_assembly` 함수는
  어셈블리를 내보내기 위한 컨테이너일 뿐 호출하지 않으므로, 스택 설정 전에 컴파일러의
  함수 프롤로그를 실행하지 않습니다. 링크 시 `--gc-sections`로 이 컨테이너를 제거합니다.
- `linker.ld`: 1 MiB부터 커널을 배치하고 `ENTRY(_start)`를 지정합니다.
  코드·읽기 전용 데이터·쓰기 가능 데이터를 별도의 ELF 로드 세그먼트로 만듭니다.

### Zig와의 차이 및 언어 검증 범위

이 포트는 출력 결과뿐 아니라 원본의 자료형과 제어 흐름을 비교하기 위한 코드입니다.
Glosso의 메서드 수신자는 `*#self`, 오류 전파는 후위 `?`이며, Zig의 `GenericWriter`는
표준 `Writer` typeclass와 `VgaWriter`의 빌린 `state: *Vga`로 옮겼습니다.
`context`는 Glosso의 예약어이므로 어댑터 필드에는 `state`라는 이름을 사용합니다.
`write`와 `print`는 표준 스트림 인터페이스의 `Io_Error` 결과를 사용합니다.

`VgaColor`는 원본처럼 `struct #packed { fg: VgaColorCode; bg: VgaColorCode; }`로
표현합니다. `enum u4` 필드는 각각 4비트이며 전경은 하위 nibble, 배경은 상위 nibble에
들어갑니다. 별도의 `bits: u8` 필드나 수동 shift 없이 `color.fg`, `color.bg`를 읽고
수정합니다. Glosso의 `#packed`는 `bool`도 1비트로 배치하며, 중첩된 packed 구조체의
필드 사이에도 padding을 넣지 않습니다. 크기와 정렬은 backing 정수형을 따릅니다.
`#c_call #packed`는 C 바인딩 호환성을 위해 기존의 바이트 packing을 유지합니다.
`VgaChar`는 `#c_call`로 문자·색상 순서를 고정하며, 색상 1바이트·셀 2바이트·정렬
1바이트를 컴파일 타임에 검사합니다.

표준 `{}` formatter를 그대로 사용하면서 x86-64 freestanding 링크에 `__udivti3`가
없던 문제가 발견되었습니다. Glosso 링커가 번들 `wide_divmodti4.c`의 128비트
나눗셈·나머지 helper를 정적으로 제공하도록 수정했습니다. libc나 별도 C 도구 설치는
필요하지 않으며, 컴파일러에 내장된 Clang과 LLD가 처리합니다.

일반 이미지는 원본처럼 보정되지 않은 busy wait를 사용합니다. Glosso 포트에서는
`pause` 명령으로 대기 루프가 최적화에 의해 사라지는 것을 막았습니다.
타이머·인터럽트 핸들러는 구현하지 않았고 인터럽트는 비활성 상태로 유지합니다.

`boot.glo`는 import 없이 별도 `--no-std --no-main --backend object` 컴파일을
수행합니다. `--no-std`는 표준 라이브러리 탐색과 암묵적인 `Prelude`·`Context` 로딩까지
비활성화합니다. 호스트 빌드 프로그램 `first.glo`의 `Compiler`·`Io` 사용 및 별도 커널
컴파일에는 영향을 주지 않습니다. 부트 오브젝트만 직접 만들려면 다음과 같이 실행합니다.

```sh
mkdir -p build/inline
../glosso/build/bin/glosso --no-std --no-main --target x86_64-freestanding \
  --backend object -O2 src/bootloader/boot.glo -o build/inline/boot.o
```

## Glosso 테스트

```sh
../glosso/build/bin/glosso --std ../glosso/std first.glo -- make-test-iso
qemu-system-x86_64 -machine pc,accel=tcg -m 128M -cdrom build/test.iso \
  -boot d -no-reboot -no-shutdown -debugcon stdio

# inline 부트 구현
../glosso/build/bin/glosso --std ../glosso/std first.glo -- make-test-iso inline
qemu-system-x86_64 -machine pc,accel=tcg -m 128M -cdrom build/inline/test.iso \
  -boot d -no-reboot -no-shutdown -debugcon stdio
```

`make-test-iso`는 `test-kernel.bin`과 `test.iso`를 선택한 출력 디렉터리에 생성합니다.
QEMU에서 이 이미지를 부팅하면 `tests/vga_test.glo`가 RAM 배열에 연결한
`Vga.buffer`로 다음을 검사합니다.

- 256개 전경·배경 조합, 실제 바이트 순서, volatile 구조체 복사와 중첩된 4비트 필드 대입.
- `bool` 1비트와 `u4`, `u3`가 한 바이트를 공유하며 volatile 갱신이 이웃 필드를 보존하는지.
- 화면 지우기, 탭·백스페이스·캐리지 리턴·줄바꿈·줄 넘김과 색상을 보존하는 스크롤.
- writer가 원래 `Vga`를 참조하는지, `{}`가 signed 64/128 최솟값과 unsigned 64/128
  최댓값을 표준 formatter와 실제 freestanding helper로 정확하게 출력하는지.

성공하면 터미널에 `[VGA language checks passed]`를 출력한 뒤 대기 루프만 생략한
원본 데모를 실행합니다. 실패하면 `!`와 오류 코드에 해당하는 문자를 출력하고 정지합니다.
테스트 결과는 터미널에서 직접 확인하고 QEMU 창을 닫아 종료합니다.
ELF 배치, 데모 출력 전체 및 실제 VGA 메모리를 자동으로 검사하는 명령은 제공하지 않습니다.
일반 실행용 커널과 ISO는 테스트 이미지와 별개입니다.

Glosso 쪽에는 `Build_Options.linker_script`와 `set_linker_script()`가 추가되어
스크립트 경로를 `-T`와 별도 인자로 전달합니다. 스크립트를 지정한 freestanding
ELF 빌드에서는 기본 `-e glo_main`을 추가하지 않아 스크립트의 `ENTRY`가 적용됩니다.
직접 `linker_args`에 `-e`를 지정하면 그 값이 우선합니다.
