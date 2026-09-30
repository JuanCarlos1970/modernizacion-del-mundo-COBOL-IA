# Imagen base: Ubuntu, porque el paquete "gnucobol3" (con soporte de
# archivos indexados habilitado) esta disponible ahi via apt. Ver
# .github/workflows/pruebas.yml para el mismo motivo de usar gnucobol3
# y no gnucobol4.
FROM ubuntu:22.04

# Evita que apt haga preguntas interactivas durante el build.
ENV DEBIAN_FRONTEND=noninteractive

# Instala GnuCOBOL (el compilador "cobc" y su runtime).
RUN apt-get update && \
    apt-get install -y gnucobol3 && \
    rm -rf /var/lib/apt/lists/*

# Carpeta de trabajo dentro del contenedor.
WORKDIR /app

# Copia todo el proyecto (codigo COBOL, casos de prueba, etc.) a /app.
COPY . .

# Compila cuenta.cbl al construir la imagen, para que quede lista para
# usar apenas se levanta un contenedor (y para detectar de una vez si
# algo no compila).
RUN mkdir -p bin && cobc -x -Wall -o bin/cuenta.exe cuenta.cbl

# Al correr el contenedor, arranca el programa interactivo de cuentas.
CMD ["./bin/cuenta.exe"]
