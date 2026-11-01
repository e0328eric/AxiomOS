#!/usr/bin/env python3
"""Boot the actual kernel and exercise its GUI through QEMU's PS/2 devices.

Uses only Python's standard library. Run after `first.glo -- make-test-iso`,
or use `first.glo -- test` to build and run everything.
"""

import argparse
import json
import os
from pathlib import Path
import select
import subprocess
import time


class Machine:
    def __init__(self, qemu, iso, output, power_actions=False, machine_type="pc"):
        self.output = output.resolve()
        self.output.mkdir(parents=True, exist_ok=True)
        self.log = self.output / "debug.log"
        self.log.write_text("")
        self.errors = (self.output / "qemu.log").open("w")
        flags = [] if power_actions else ["-no-reboot", "-no-shutdown"]
        self.process = subprocess.Popen(
            [qemu, "-machine", machine_type, "-m", "128M", "-cdrom", str(iso.resolve()), "-boot", "d",
             "-vga", "std", "-display", "none", *flags,
             "-debugcon", f"file:{self.log}", "-qmp", "stdio"],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=self.errors,
            bufsize=0,
        )
        self.pending = b""
        self.sequence = 0
        self.events = []

    def read(self, timeout=10):
        deadline = time.monotonic() + timeout
        while b"\n" not in self.pending:
            remaining = deadline - time.monotonic()
            if remaining <= 0 or not select.select([self.process.stdout], [], [], remaining)[0]:
                raise TimeoutError("QEMU monitor timed out")
            chunk = os.read(self.process.stdout.fileno(), 65536)
            if not chunk:
                raise RuntimeError("QEMU exited; see " + str(self.output / "qemu.log"))
            self.pending += chunk
        line, self.pending = self.pending.split(b"\n", 1)
        result = json.loads(line)
        if "event" in result:
            self.events.append(result)
        return result

    def command(self, command, arguments=None):
        self.sequence += 1
        payload = {"execute": command, "arguments": arguments or {}, "id": self.sequence}
        self.process.stdin.write((json.dumps(payload) + "\n").encode())
        while True:
            result = self.read()
            if result.get("id") != self.sequence:
                continue
            if "error" in result:
                raise RuntimeError(result["error"])
            return result["return"]

    def boot(self, self_tests):
        assert "QMP" in self.read()
        self.command("qmp_capabilities")
        deadline = time.monotonic() + 20
        while time.monotonic() < deadline:
            log = self.log.read_text()
            if "[Self-test failed:" in log:
                raise AssertionError(log)
            if "[Desktop ready]" in log:
                break
            time.sleep(0.1)
        else:
            raise AssertionError(f"Desktop did not boot: {self.command('query-status')}\n{log}")
        for marker in ("[Framebuffer ready]", "[Keyboard ready]", "[Mouse ready]"):
            assert marker in log, log
        if self_tests:
            assert "[VGA language checks passed]" in log, log
            assert "[GUI checks passed]" in log, log
            assert "[Power checks passed]" in log, log
        assert self.command("query-status")["running"]
        image = self.screenshot("desktop")
        self.x, self.y = image.width // 2, image.height // 2
        return image

    def screenshot(self, name):
        time.sleep(0.15)
        path = self.output / (name + ".ppm")
        self.command("screendump", {"filename": str(path)})
        return Image(path)

    def key(self, *keys):
        self.command("send-key", {
            "keys": [{"type": "qcode", "data": key} for key in keys], "hold-time": 30,
        })
        time.sleep(0.09)

    def move(self, x, y):
        # Small deltas also exercise packet assembly without overflowing PS/2.
        while (self.x, self.y) != (x, y):
            dx = max(-80, min(80, x - self.x))
            dy = max(-80, min(80, y - self.y))
            self.command("input-send-event", {"events": [
                {"type": "rel", "data": {"axis": "x", "value": dx}},
                {"type": "rel", "data": {"axis": "y", "value": dy}},
            ]})
            self.x += dx
            self.y += dy
            time.sleep(0.04)

    def button(self, down):
        self.command("input-send-event", {"events": [
            {"type": "btn", "data": {"button": "left", "down": down}},
        ]})
        time.sleep(0.08)

    def click(self, x, y):
        self.move(x, y)
        self.button(True)
        self.button(False)

    def close(self):
        try:
            if self.process.poll() is None:
                self.command("quit")
                self.process.wait(timeout=5)
        finally:
            if self.process.poll() is None:
                self.process.kill()
                self.process.wait()
            self.errors.close()

    def wait_reboot(self, count):
        deadline = time.monotonic() + 20
        while time.monotonic() < deadline:
            log = self.log.read_text()
            if log.count("[Desktop ready]") >= count:
                break
            time.sleep(0.1)
        else:
            raise AssertionError("Guest did not reboot:\n" + log)
        assert log.count("[Restart requested]") == count - 1, log
        assert "[Power action failed]" not in log, log
        assert self.command("query-status")["running"]
        assert any(e["event"] == "RESET" and e.get("data", {}).get("guest") for e in self.events)
        image = self.screenshot(f"reboot-{count}")
        self.x, self.y = image.width // 2, image.height // 2
        return image

    def wait_poweroff(self):
        try:
            code = self.process.wait(timeout=10)
        except subprocess.TimeoutExpired as error:
            raise AssertionError("Guest did not power off:\n" + self.log.read_text()) from error
        assert code == 0, code
        log = self.log.read_text()
        assert "[Power off requested]" in log and "[Power action failed]" not in log, log
        # QMP is used only to observe the guest's ACPI shutdown, never to request it.
        tail = self.pending + self.process.stdout.read()
        for line in tail.splitlines():
            result = json.loads(line)
            if "event" in result:
                self.events.append(result)
        assert any(e["event"] == "SHUTDOWN" and e.get("data", {}).get("guest") for e in self.events), self.events


class Image:
    def __init__(self, path):
        with path.open("rb") as file:
            assert file.readline().strip() == b"P6"
            dimensions = file.readline()
            while dimensions.startswith(b"#"):
                dimensions = file.readline()
            self.width, self.height = map(int, dimensions.split())
            assert file.readline().strip() == b"255"
            self.pixels = file.read()
            assert len(self.pixels) == self.width * self.height * 3

    def pixel(self, x, y):
        offset = (y * self.width + x) * 3
        return int.from_bytes(self.pixels[offset:offset + 3], "big")

    def glyph(self, x, y, rows):
        # Assert the rendered glyph, rather than only observing changed pixels.
        for row, bits in enumerate(rows):
            for col in range(5):
                expected = 0x1E293B if bits & (16 >> col) else 0xFFFFFF
                actual = self.pixel(x + col * 2, y + row * 2)
                assert actual == expected, ("glyph", x, y, row, col, hex(actual), hex(expected))


def check(machine, self_tests):
    image = machine.boot(self_tests)
    assert (image.width, image.height) == (800, 600)
    assert image.pixel(0, 0) == 0x0F1B2D
    assert image.pixel(50, 90) == 0x0F766E
    machine.key("a")
    machine.key("b")
    machine.key("shift", "c")
    image = machine.screenshot("typing")
    image.glyph(72, 160, [0, 0, 14, 1, 15, 17, 15])
    image.glyph(84, 160, [16, 16, 30, 17, 17, 17, 30])
    image.glyph(96, 160, [14, 17, 16, 16, 16, 17, 14])
    machine.key("backspace")
    machine.key("ret")
    machine.key("x")
    image = machine.screenshot("editing")
    image.glyph(72, 178, [0, 0, 17, 10, 4, 10, 17])
    image.glyph(96, 160, [0] * 7)

    machine.key("tab")
    machine.key("z")
    image = machine.screenshot("focus")
    assert image.pixel(50, 90) == 0x475569
    image.glyph(84, 178, [0] * 7)  # The unfocused editor must not receive Z.

    machine.move(160, 100)
    machine.button(True)
    machine.move(256, 160)
    machine.button(False)
    image = machine.screenshot("dragging")
    assert image.pixel(150, 150) == 0x0F766E
    assert image.pixel(50, 90) == 0x16263B
    image.glyph(168, 220, [0, 0, 14, 1, 15, 17, 15])

    machine.click(514, 144)
    image = machine.screenshot("stacking")
    assert image.pixel(150, 150) == 0x475569
    assert image.pixel(480, 134) == 0x0F766E
    machine.click(740, 144)
    image = machine.screenshot("closed")
    assert image.pixel(700, 134) == 0x16263B
    assert image.pixel(150, 150) == 0x0F766E
    machine.click(170, 580)
    image = machine.screenshot("reopened")
    assert image.pixel(700, 134) == 0x0F766E

    machine.key("f1")
    machine.move(200, 160)
    machine.button(True)
    machine.move(0, 0)
    machine.button(False)
    image = machine.screenshot("clamped")
    assert image.pixel(2, 58) == 0x0F766E
    assert machine.command("query-status")["running"]
    print("PASS: boot, framebuffer, PS/2 typing, Shift, Backspace, Enter, focus, drag, stacking, close/reopen, screen bounds")
    print(f"Screenshots and boot log: {machine.output}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--qemu", default=os.environ.get("QEMU", "qemu-system-x86_64"))
    parser.add_argument("--iso", type=Path, default=Path("build/test.iso"))
    parser.add_argument("--output", type=Path, default=Path("build/gui-smoke"))
    parser.add_argument("--skip-self-tests", action="store_true")
    args = parser.parse_args()
    machine = Machine(args.qemu, args.iso, args.output, power_actions=True)
    try:
        check(machine, not args.skip_self_tests)
        assert "[ACPI power off ready]" in machine.log.read_text()
        machine.click(610, 24)
        machine.wait_reboot(2)
        # Input and the editor must work after a guest-initiated reboot.
        machine.key("a")
        machine.screenshot("after-reboot-typing").glyph(72, 160, [0, 0, 14, 1, 15, 17, 15])
        machine.key("f10")
        machine.wait_reboot(3)
        machine.key("f12")
        machine.wait_poweroff()
        print("PASS: desktop Restart, F10 restart, input after reboot, F12 ACPI power off")
    finally:
        machine.close()
    # Also cover modern FADT fields and a different PC chipset's reset path.
    machine = Machine(args.qemu, args.iso, args.output / "q35", power_actions=True, machine_type="q35")
    try:
        machine.boot(not args.skip_self_tests)
        assert "[ACPI power off ready]" in machine.log.read_text()
        machine.key("f10")
        machine.wait_reboot(2)
        machine.move(730, 24)
        machine.button(True)  # The VM exits on press, so no release is sent.
        machine.wait_poweroff()
        print("PASS: Q35 guest restart and desktop Power off button")
    finally:
        machine.close()


if __name__ == "__main__":
    main()
