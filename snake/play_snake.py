#!/usr/bin/env python3
import os
import sys
import time
import socket
import select
import tty
import termios
import subprocess

def main():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(base_dir)

    print("=== STX4 Bare-Metal Snake Launcher (RTM32 v0.5) ===")
    
    # 1. Ensamblar juego a snake.bin (con snapshot header)
    print("[1/4] Ensamblando snake_all.rtm -> snake.bin...")
    res = subprocess.run(["./rtm32.asm", "snake/snake_all.rtm", "-o", "snake/snake.bin"], capture_output=True, text=True)
    if res.returncode != 0:
        print("Error en el ensamblado:")
        print(res.stderr or res.stdout)
        return
    print("      Ensamblado exitoso.")

    # 2. Iniciar rtm32
    print("[2/4] Iniciando emulador rtm32...")
    emu = subprocess.Popen(
        ["./rtm32", "-d", "telnet", "-p", "50001"],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True
    )

    pts = None
    while True:
        line = emu.stdout.readline()
        if "UART available on" in line:
            pts = line.split("UART available on ")[1].strip()
        if "Waiting for a debugger" in line or "Waiting for remote debugger" in line:
            break

    if not pts:
        print("Error: No se pudo obtener el puerto UART /dev/pts.")
        emu.kill()
        return

    print(f"      UART detectado en: {pts}")

    # 3. Conectar al debugger, responder Telnet IAC y cargar snapshot
    print("[3/4] Conectando a debugger en puerto 50001...")
    time.sleep(0.3)
    s = socket.socket()
    s.connect(("localhost", 50001))
    s.settimeout(0.5)
    try:
        s.recv(1024)
    except:
        pass
    s.sendall(b"\xff\xfe\x01")
    time.sleep(0.05)
    s.sendall(b"\xff\xfe\x03\xff\xfc\x03")
    time.sleep(0.05)
    s.settimeout(0.5)
    try:
        s.recv(1024)
    except:
        pass

    # Finish handshake
    s.sendall(b"\n")
    time.sleep(0.1)

    # Cargar snapshot y continuar
    s.sendall(b"load snake/snake.bin\n")
    time.sleep(0.1)
    s.settimeout(0.5)
    try:
        s.recv(1024)
    except:
        pass
    print("      Enviando comando 'continue' a la CPU...")
    s.sendall(b"continue\n")

    # 4. Abrir PTY para I/O
    print("[4/4] Conectando terminal al juego. Controles: [W, A, S, D] | Salir: [Ctrl+C]")
    time.sleep(0.1)

    pty_fd = os.open(pts, os.O_RDWR | os.O_NONBLOCK)
    tty.setraw(pty_fd)

    stdin_fd = sys.stdin.fileno()
    old_attr = termios.tcgetattr(stdin_fd)

    try:
        tty.setraw(stdin_fd)
        while True:
            rlist, _, _ = select.select([stdin_fd, pty_fd], [], [], 0.02)
            
            if stdin_fd in rlist:
                ch = os.read(stdin_fd, 1)
                if ch in [b'\x03', b'\x1b']:  # Ctrl+C o ESC
                    break
                os.write(pty_fd, ch)

            if pty_fd in rlist:
                out = os.read(pty_fd, 1024)
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
        except:
            pass
        emu.terminate()
        emu.wait()
        print("\n\nJuego terminado y emulador detenido limpiamente.")

if __name__ == "__main__":
    main()
