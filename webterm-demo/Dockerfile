# Dockerfile de la DEMO WEB (terminal en el navegador sobre el programa COBOL).
# Vive en la carpeta webterm-demo/, pero se construye desde la RAIZ del repo,
# porque necesita cuenta.cbl, que esta en la raiz:
#
#   docker build -f webterm-demo/Dockerfile -t cobol-web-demo .
#   docker run -p 5000:5000 cobol-web-demo
#
# Mismo comando de compilacion que el Dockerfile original del proyecto
# (-Wall, sin -free porque el codigo esta en formato fijo de columnas).

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# GnuCOBOL (compilador cobc) + Python3 y pip (para Flask).
RUN apt-get update && \
    apt-get install -y gnucobol3 python3 python3-pip && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copia todo el repo (codigo COBOL, pruebas, etc.) a /app.
COPY . .

# Compila el programa COBOL.
RUN mkdir -p bin && \
    cobc -x -Wall -o bin/cuenta.exe cuenta.cbl

# Librerias Python de la interfaz web.
COPY webterm-demo/requirements.txt /app/requirements_web.txt
RUN pip3 install --no-cache-dir -r /app/requirements_web.txt

# Codigo de la interfaz web: servidor, pagina y librerias JS locales (sin CDN).
COPY webterm-demo/app.py /app/app.py
COPY webterm-demo/templates/ /app/templates/
COPY webterm-demo/static/ /app/static/

ENV COBOL_BINARY_PATH=/app/bin/cuenta.exe
ENV PORT=5000
EXPOSE 5000

CMD ["python3", "app.py"]
