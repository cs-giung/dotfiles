"""Run: python3 nvim/tests/sixel_flush.py (Linux, installed Neovim plugins + magick).

Uses a real Neovim TUI in a private PTY and captures the emitted Sixel packet.
This proves flush scheduling and TUI byte delivery, not visual terminal support.
"""
import fcntl
import json
import os
from pathlib import Path
import pty
import re
import select
import struct
import subprocess
import tempfile
import termios
import time

fixture = Path(__file__).with_suffix(".lua").resolve()


def run_case(directory, overlap):
    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 20, 104, 832, 320))
    result = directory / f"result-{overlap}.json"
    env = dict(os.environ, TERM="xterm-256color", TEST_OVERLAP=str(overlap),
               TEST_PNG=str(directory / "test.png"), TEST_RESULT=str(result))
    # This is a direct private PTY, not a pane in the caller's tmux server.
    env.pop("TMUX", None)
    env.pop("TMUX_PANE", None)
    process = subprocess.Popen(
        ["nvim", "-u", "NONE", "-i", "NONE", "-n", "-c", f"luafile {fixture}"],
        stdin=slave, stdout=slave, stderr=slave, env=env, start_new_session=True,
    )
    os.close(slave)
    output = bytearray()
    try:
        deadline = time.monotonic() + 15
        while process.poll() is None and time.monotonic() < deadline:
            if select.select([master], [], [], 0.1)[0]:
                try:
                    output.extend(os.read(master, 65536))
                except OSError:
                    break
        process.wait(timeout=2)
        assert process.returncode == 0, repr(bytes(output[-2000:]))
        assert result.exists(), repr(bytes(output[-2000:]))
        packet = re.search(rb"\x1b\[s\x1b\[[0-9]+;[0-9]+H\x1bP[0-?]*q[ -~]*?\x1b\\\x1b\[u", output)
        assert packet, "TUI did not emit an intact Sixel packet to its terminal"
        return json.loads(result.read_text())
    finally:
        if process.poll() is None:
            process.kill()
        process.wait()
        os.close(master)


with tempfile.TemporaryDirectory() as temporary:
    directory = Path(temporary)
    subprocess.run(["magick", "-size", "320x128", "xc:red", str(directory / "test.png")], check=True)
    old = run_case(directory, 1)
    current = run_case(directory, 0)
    assert old["checkpoint"]["renders"] > 5 and old["checkpoint"]["sends"] == 0, old
    assert current["checkpoint"]["sends"] > 0 and current["checkpoint"]["painted"], current
    assert current["checkpoint"]["renders"] <= 3, current
    print("sixel_flush: old overlap polling starves flush during redraws:", old["checkpoint"])
    print("sixel_flush: current configuration flushes without repeated render requests:", current["checkpoint"])
