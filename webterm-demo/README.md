# Demo web: terminal en el navegador sobre el programa COBOL

Interfaz web que muestra el programa `cuenta` (Gestion de Cuentas Bancarias) dentro de una
terminal en el navegador. Es un enfoque de *rehosting*: no se modifica ni una linea del COBOL.

## Como funciona
- `app.py`: servidor Flask + Flask-SocketIO. Por cada usuario lanza `cuenta.exe` dentro de una
  pseudo-terminal (pty) y reenvia por WebSocket lo que el programa imprime y lo que el usuario tipea.
- `templates/index.html`: la pagina, con una terminal visual (xterm.js).
- `static/`: xterm.js, su addon de ajuste y el cliente de socket.io, incluidos en el repo
  (no dependen de ningun CDN externo).
- `Dockerfile`: GnuCOBOL + Python en un mismo contenedor.

## Como probarlo (requiere Docker)
Desde la **raiz del repo**:

```
docker build -f webterm-demo/Dockerfile -t cobol-web-demo .
docker run -p 5000:5000 cobol-web-demo
```

Abrir http://localhost:5000

## Notas
- Los datos que se cargan viven dentro del contenedor y se pierden al detenerlo
  (para persistirlos habria que montar un volumen con `docker run -v`).
- Despliegue real: AWS EC2. En Azure, la cuenta de prueba gratuita no permite VM ni contenedores
  en App Service sin pasar a pago, por lo que se descarto.
