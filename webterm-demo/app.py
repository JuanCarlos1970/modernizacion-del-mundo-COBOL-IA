"""
Interfaz web tipo "terminal" para el programa COBOL de Gestion de Cuentas Bancarias.

Que hace este archivo:
- Levanta un servidor web con Flask.
- Cuando alguien abre la pagina, el navegador se conecta por WebSocket (Flask-SocketIO).
- Por cada usuario conectado, lanzamos el ejecutable COBOL "cuenta" dentro de una
  pseudo-terminal (pty), exactamente como si lo hubieras corrido vos en la consola.
- Todo lo que el programa COBOL imprime se manda en tiempo real al navegador.
- Todo lo que el usuario tipea en la paginita se manda en tiempo real al programa COBOL,
  como si lo hubiera tipeado en el teclado de la consola.

Por eso el comportamiento es identico al de la consola (mismo menu, mismos pedidos de
datos), solo que ahora se ve en una pagina web en vez de en tu terminal local.
"""

# IMPORTANTE: esto tiene que ser lo PRIMERO que se ejecuta en el archivo, antes de
# importar "os", "select", etc. Flask corre con "eventlet" (motor que atiende a muchos
# usuarios conectados a la vez sin usar un hilo de sistema operativo por cada uno). Para
# que eso funcione, eventlet necesita "parchear" por dentro las funciones normales de
# Python que se quedan esperando datos (como leer el pty o el socket), para que sean
# cooperativas en vez de bloquear todo el servidor. Si esto no se hace ANTES de todo,
# el servidor se queda "trabado" esperando al programa COBOL y nunca le manda nada al
# navegador (por eso la terminal se veia vacia, sin el menu).
import eventlet
eventlet.monkey_patch()

import os
import pty
import select
import subprocess
import struct
import fcntl
import termios

from flask import Flask, render_template
from flask_socketio import SocketIO

# Ruta al ejecutable COBOL dentro del contenedor/servidor Linux.
# En Azure/Docker va a estar en /app/bin/cuenta (lo copiamos ahi en el Dockerfile).
COBOL_BINARY = os.environ.get("COBOL_BINARY_PATH", "/app/bin/cuenta")

app = Flask(__name__)
app.config["SECRET_KEY"] = "cambiar-esto-en-produccion"
socketio = SocketIO(app, async_mode="eventlet")

# Guardamos, por cada cliente conectado (sid), el file descriptor del pty y el pid del proceso.
sesiones = {}


def leer_salida_proceso(sid, fd):
    """Lee lo que el programa COBOL va imprimiendo y se lo manda al navegador por WebSocket."""
    max_leer = 1024 * 20
    while True:
        try:
            datos_listos, _, _ = select.select([fd], [], [], 1)
        except (OSError, ValueError):
            break
        if not datos_listos:
            # Nada nuevo en este segundo, seguimos esperando (el proceso puede seguir vivo).
            if sid not in sesiones:
                break
            continue
        try:
            salida = os.read(fd, max_leer)
        except OSError:
            break
        if not salida:
            break
        socketio.emit("salida_terminal", salida.decode(errors="ignore"), to=sid)
    socketio.emit("proceso_terminado", {}, to=sid)


@app.route("/")
def index():
    return render_template("index.html")


@socketio.on("connect")
def al_conectar():
    sid = request_sid()
    # pty.fork() crea un proceso hijo conectado a una terminal "falsa" (pseudo-terminal).
    # Esto es necesario porque el programa COBOL espera una terminal interactiva real,
    # no una simple tuberia (pipe), para mostrar el menu y leer el teclado correctamente.
    pid, fd = pty.fork()
    if pid == 0:
        # Codigo que corre DENTRO del proceso hijo: reemplaza este proceso por el programa COBOL.
        os.execv(COBOL_BINARY, [COBOL_BINARY])
    else:
        # Codigo que corre en el proceso del servidor Flask (el padre).
        sesiones[sid] = {"fd": fd, "pid": pid}
        socketio.start_background_task(leer_salida_proceso, sid, fd)


@socketio.on("entrada_terminal")
def al_recibir_input(data):
    """El navegador nos manda lo que el usuario tipeo; se lo pasamos al programa COBOL."""
    sid = request_sid()
    sesion = sesiones.get(sid)
    if not sesion:
        return
    try:
        os.write(sesion["fd"], data.encode())
    except OSError:
        pass


@socketio.on("resize_terminal")
def al_redimensionar(data):
    """Si el usuario cambia el tamano de la ventana del navegador, avisamos al pty."""
    sid = request_sid()
    sesion = sesiones.get(sid)
    if not sesion:
        return
    filas = int(data.get("rows", 24))
    columnas = int(data.get("cols", 80))
    winsize = struct.pack("HHHH", filas, columnas, 0, 0)
    try:
        fcntl.ioctl(sesion["fd"], termios.TIOCSWINSZ, winsize)
    except OSError:
        pass


@socketio.on("disconnect")
def al_desconectar():
    sid = request_sid()
    sesion = sesiones.pop(sid, None)
    if sesion:
        try:
            os.close(sesion["fd"])
        except OSError:
            pass
        try:
            os.kill(sesion["pid"], 9)
        except OSError:
            pass


def request_sid():
    from flask import request
    return request.sid


if __name__ == "__main__":
    puerto = int(os.environ.get("PORT", 5000))
    socketio.run(app, host="0.0.0.0", port=puerto)
