# AxiomOS in Glosso

AxiomOS는 Glosso로 작성한 x86-64 Multiboot2 OS입니다.
GRUB의 BIOS 부팅 경로와 픽셀 프레임버퍼를 사용해 작은 데스크톱을 표시합니다.
PS/2 키보드·마우스, 드래그 가능한 창 두 개, 메모 입력창과 작업 표시줄을 지원합니다.
원본 MIT 라이선스를 유지합니다.

## 데스크톱 사용

- 창을 클릭하면 해당 창에 키보드 포커스가 이동합니다.
- 제목 표시줄을 드래그하면 창이 이동하고, `x`를 누르면 닫힙니다.
- 작업 표시줄의 `Notes` 또는 `Welcome`을 누르면 창이 다시 열립니다.
- `Notes`에서 영문/숫자/기호를 입력합니다. Shift, Caps Lock, Enter, Backspace를 지원합니다.
- Tab은 열린 창 사이를 이동하고, F1은 두 창을 다시 엽니다.
- 화면 오른쪽 위의 `Restart` 또는 F10으로 OS를 재부팅합니다.
- `Power off` 또는 F12로 OS에서 ACPI 종료를 요청합니다. QEMU에서는 VM 창도 닫힙니다.

메모는 최대 1,024 ASCII 문자이며 줄바꿈과 자동 스크롤을 지원합니다.
창을 닫아도 내용은 유지되지만 재부팅하면 사라집니다.
재부팅·종료는 별도 확인 없이 바로 실행되며, 메모는 저장되지 않습니다.
지원되는 ACPI 종료 정보를 찾지 못하면 `Power off` 버튼은 회색으로 표시됩니다.

## 빌드와 실행

Linux 호스트에서 수정된 Glosso 컴파일러, GRUB의 `i386-pc` 모듈과
`grub-mkrescue`, fasm, xorriso, QEMU가 필요합니다. 자동 테스트에는 Python 3도 필요합니다.
Zig와 외부 `ld`/`ld.lld`는 사용하지 않습니다. Glosso는 내장 LLD를 포함한 빌드를 사용하세요.

먼저 이 변경을 포함한 Glosso를 빌드합니다.

```sh
cd ../glosso
./build.exe build
cd ../AxiomOS
```

NixOS에서는 이 디렉터리에서 `nix-shell`로 도구 환경에 들어갈 수 있습니다.
아래 명령은 모두 **이 저장소의 루트 디렉터리에서** 실행합니다.

```sh
# 커널 ELF만 생성: build/kernel.bin
../glosso/build/bin/glosso --std ../glosso/std first.glo

# 커널을 빌드하고 부팅 ISO 생성: AxiomOS.iso
../glosso/build/bin/glosso --std ../glosso/std first.glo -- make-iso

# 빌드 → ISO → QEMU 창에서 부팅
../glosso/build/bin/glosso --std ../glosso/std first.glo -- run-qemu

# 커널 검사 + 화면 없는 QEMU에서 실제 키보드/마우스 조작 테스트
../glosso/build/bin/glosso --std ../glosso/std first.glo -- test
```

설치된 `glosso`와 표준 라이브러리가 이 변경을 포함하면 `glosso first.glo`로도
실행할 수 있습니다. 기존 설치본에는 `linker_script`나 `--no-std`가 없을 수 있으므로
위 예시는 저장소에서 빌드한 컴파일러와 표준 라이브러리를 명시합니다.

산출물은 `build/`와 `AxiomOS.iso`에 저장합니다. 부트 코드는 fasm으로 조립하고,
커널과 장치 I/O는 Glosso로 작성합니다.

| `first.glo --` 뒤의 명령 | 동작 |
|---|---|
| `build` 또는 생략 | 부트 오브젝트와 Glosso 커널을 빌드·링크 |
| `make-iso` | 빌드 후 GRUB ISO 생성 |
| `make-test-iso` | VGA·프레임버퍼·입력·창 상태 검사가 포함된 `build/test.iso` 생성 |
| `run-qemu` | ISO 생성 후 QEMU 실행, 부팅 상태를 `build/debug.log`에 기록 |
| `test` | 테스트 ISO를 만들고 QEMU에서 GUI 조작 검증 |
| `clean` | 빌드 산출물 제거 |
| `help` | 명령 목록 표시 |

`FASM`, `GRUB_MKRESCUE`, `QEMU`, `PYTHON` 환경 변수로 각 도구의 실행 파일을
지정할 수 있습니다. 파일 경로에 공백이 있어도 하나의 인자로 전달합니다.

## 구현과 테스트

| 파일 | 역할 |
|---|---|
| `src/bootloader/boot.asm` | 프레임버퍼 요청, Multiboot2 포인터 전달, 4 GiB 초기 메모리 매핑 |
| `src/kernel/Framebuffer.glo` | 부팅 정보 검증, 클리핑, RAM 버퍼와 화면 복사 |
| `src/kernel/Font.glo` | 5×7 ASCII 비트맵 글꼴 |
| `src/kernel/Ps2.glo` | i8042 초기화, 키보드·마우스 데이터 디코딩 |
| `src/kernel/Power.glo` | ACPI 테이블에서 종료·리셋 레지스터 탐색, S5 종료 및 PC 리셋 |
| `src/kernel/Desktop.glo` | 창 그리기, 포커스, 드래그, 메모와 작업 표시줄 |
| `src/kernel/kmain.glo` | 초기화 및 입력/그리기 루프 |

`test`는 기존 VGA 검사와 함께 잘못된 부팅 정보, RGB 순서, 행 간격,
화면 경계, 키 해제/Shift/Caps Lock, 마우스 부호와 오버플로,
창 포커스 및 입력 길이를 검사합니다. 이어서 QEMU QMP로 실제 입력을 보내고
렌더링된 글자와 창 위치를 스크린샷에서 확인합니다.
ACPI 체크섬, RSDT/XSDT, FADT 확장 레지스터, 잘못된 AML 및 종료 단축키도 검사합니다.
QEMU PC와 Q35에서 OS의 버튼과 키보드로 재부팅·종료하고, 게스트가 발생시킨
RESET/SHUTDOWN 이벤트와 재부팅 후 입력 동작을 확인합니다.
로그와 PPM 스크린샷은 `build/gui-smoke/`에 저장됩니다.

현재 대상은 QEMU의 BIOS PC, 표준 VGA 및 PS/2 장치입니다.
32비트 직접 RGB 프레임버퍼(640×480부터 1280×1024, 물리 주소 4 GiB 미만)를 지원하며
기본 모드는 800×600입니다. 지원되지 않는 화면 모드는 디버그 로그에 이유를 남기고 정지합니다.
고정 크기 버퍼를 사용하고 인터럽트 없이 입력을 폴링하므로 대기 중에도 CPU를 사용합니다.
USB 입력, 창 크기 조절, 파일 저장 및 실제 하드웨어 검증은 아직 포함하지 않습니다.

종료는 Multiboot2의 ACPI RSDP에서 RSDT/XSDT, FADT, DSDT를 찾아 PM1 제어 포트와
루트 `\_S5` 상수 패키지를 읽습니다. 재부팅은 지원되는 ACPI 리셋 레지스터를 우선 사용하고,
실패하거나 지원되지 않으면 i8042 리셋 명령을 사용합니다.
현재 ACPI 지원은 BIOS PC의 I/O 포트 기반 PM1 제어와 상수 `\_S5`에 한정됩니다.
전체 AML 실행기, `_PTS` 같은 펌웨어 메서드 실행 및 하드웨어 축소 ACPI는 지원하지 않습니다.
부팅 설정은 ACPI 테이블과 프레임버퍼가 4 GiB 아래에 있어야 합니다.
`run-qemu`는 게스트의 재부팅·종료가 실제로 작동하도록 `-no-reboot`와 `-no-shutdown`을 사용하지 않습니다.
