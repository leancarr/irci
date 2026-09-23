#!/usr/bin/env python3
"""Launcher Snake STX4 para el layout irci (cpu/ + snake/).

1. Ensambla snake_build.asm -> /tmp/snake.bin (formato MDBG via assembler.py)
2. Arranca rtm32 en modo telnet (puerto 50001) con el binario que encuentre:
   ./rtm32, ../rtm32, PATH, o Koba/cpu-koba/cpu-nuevo-koba/rtm32
3. Carga con `load`, manda `continue` y puentea tu teclado <-> UART (PTY).
Controles: W A S D (mayus o minus). Salir: Ctrl+C o ESC.
"""
import os
import sys
import time
import socket
import select
import shutil
import subprocess
import tty
import termios

IRCI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASM = os.path.join(IRCI, "cpu", "assembler.py")
SRC = os.path.join(IRCI, "snake", "snake_build.asm")
BIN = "/tmp/snake_irci.bin"
KOBA_RTM32 = "/home/leancarr/Escritorio/Proyectos-Mios/Koba/cpu-koba/cpu-nuevo-koba/rtm32"


def find_rtm32():
    for c in (os.path.join(IRCI, "snake", "rtm32"),
              os.path.join(IRCI, "rtm32"),
              shutil.which("rtm32"),
              KOBA_RTM32):
        if c and os.path.isfile(c) and os.access(c, os.X_OK):
            return c
    return None


def wait_line(stream, needles, timeout=15):
    out = ""
    t0 = time.time()
    while time.time() - t0 < timeout:
        line = stream.readline()
        if not line:
            time.sleep(0.05)
            continue
        out += line
        if all(n in out for n in needles):
            return out
    raise RuntimeError("timeout esperando emulador. Leido:\n" + out[-2000:])


def dbg_send(s, cmd, timeout=30):
    s.sendall(cmd.encode() + b"\n")
    data = b""
    t0 = time.time()
    while time.time() - t0 < timeout:
        try:
            chunk = s.recv(65536)
        except socket.timeout:
            break
        if not chunk:
            break
        data += chunk
        if data.rstrip().endswith(b"RTM32>"):
            break
    return data.decode("latin-1", errors="replace")


def main():
    print("=== Snake STX4 (irci) ===")
    rtm32 = find_rtm32()
    if not rtm32:
        print("No encuentro el binario rtm32. Copialo asi:")
        print(f"  cp {KOBA_RTM32} {os.path.join(IRCI, 'snake', 'rtm32')}")
        sys.exit(1)
    print(f"[1/4] rtm32: {rtm32}")

    print("[2/4] Ensamblando snake_build.asm ->", BIN)
    res = subprocess.run([sys.executable, ASM, SRC, BIN],
                         capture_output=True, text=True)
    print("      " + (res.stdout.strip() or res.stderr.strip()))
    if res.returncode != 0 or not os.path.isfile(BIN):
        print("Fallo el ensamblado."); sys.exit(1)

    print("[3/4] Iniciando emulador...")
    emu = subprocess.Popen(
        ["stdbuf", "-o0", "-e0", rtm32, "-d", "telnet"],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    try:
        boot = wait_line(emu.stdout, ["UART available on", "listening on port"])
    except RuntimeError as e:
        print(str(e)); emu.terminate(); sys.exit(1)
    pts = boot.split("UART available on ")[1].split()[0].strip()
    print(f"      UART en: {pts}")
    if not os.path.exists(pts):
        print(f"OJO: {pts} no existe en este entorno; el juego puede no mostrarse.")
        print("Si pasa, juga desde una terminal local (no remota/contenedor).")

    s = socket.socket()
    s.settimeout(5)
    t0 = time.time()
    while True:
        try:
            s.connect(("127.0.0.1", 50001))
            break
        except OSError:
            if time.time() - t0 > 10:
                print("No hay debugger en 50001."); emu.terminate(); sys.exit(1)
            time.sleep(0.3)
    s.settimeout(0.5)
    try:
        s.recv(4096)
    except socket.timeout:
        pass
    s.sendall(b"\xff\xfe\x01")
    time.sleep(0.05)
    s.sendall(b"\xff\xfe\x03\xff\xfc\x03")
    time.sleep(0.05)
    try:
        s.recv(4096)
    except socket.timeout:
        pass
    s.sendall(b"\n")
    time.sleep(0.2)
    s.settimeout(30)
    data = b""
    t0 = time.time()
    while b"RTM32>" not in data and time.time() - t0 < 5:
        try:
            data += s.recv(4096)
        except socket.timeout:
            break
    print(dbg_send(s, f"load {BIN}").strip().splitlines()[-2:])
    print("[4/4] Arrancando CPU... Controles W A S D | Salir Ctrl+C o ESC")
    # `continue` NO devuelve prompt (el juego corre infinito): fire-and-forget
    s.sendall(b"continue\n")
    time.sleep(0.5)

    pty_fd = os.open(pts, os.O_RDWR | os.O_NONBLOCK)
    stdin_fd = sys.stdin.fileno()
    old_attr = termios.tcgetattr(stdin_fd)
    try:
        tty.setraw(stdin_fd)
        while True:
            rlist, _, _ = select.select([stdin_fd, pty_fd], [], [], 0.02)
            if stdin_fd in rlist:
                ch = os.read(stdin_fd, 1)
                if ch in [b"\x03", b"\x1b"]:
                    break
                os.write(pty_fd, ch)
            if pty_fd in rlist:
                try:
                    out = os.read(pty_fd, 1024)
                except OSError:
                    out = b""
                if out:
                    sys.stdout.buffer.write(out)
                    sys.stdout.buffer.flush()
            if emu.poll() is not None:
                break
    finally:
        termios.tcsetattr(stdin_fd, termios.TCSADRAIN, old_attr)
        os.close(pty_fd)
        try:
            s.sendall(b"quit\n")
            s.close()
        except OSError:
            pass
        emu.terminate()
        emu.wait()
        print("\nJuego terminado.")


if __name__ == "__main__":
    main()
