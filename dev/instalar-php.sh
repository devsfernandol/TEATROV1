#!/usr/bin/env bash
# Compila PHP desde el código fuente oficial de php.net dentro de .dev/php,
# sin sudo y sin tocar el PHP del sistema. Verifica el SHA-256 publicado por php.net.
#
# Uso: dev/instalar-php.sh [versión]   (por defecto la indicada en dev/entorno.sh)
#
# Requiere: gcc, make, curl y python3 (paquete build-essential).

set -euo pipefail
source "$(dirname "$0")/entorno.sh"

VERSION="${1:-$PHP_VERSION}"
ARCHIVO="php-$VERSION.tar.gz"
DESCARGAS="$DEV_DIR/descargas"
FUENTES="$DEV_DIR/php-src-$VERSION"
DESTINO="$DEV_DIR/php"

if [[ -x "$DESTINO/bin/php" ]] \
    && [[ "$("$DESTINO/bin/php" -r 'echo PHP_VERSION;')" == "$VERSION" ]] \
    && "$DESTINO/bin/php" -r 'exit(extension_loaded("openssl") ? 0 : 1);'; then
    echo "✓ PHP $VERSION ya está instalado en .dev/php"
    exit 0
fi

mkdir -p "$DESCARGAS"

echo "→ Consultando el SHA-256 oficial de PHP $VERSION en php.net ..."
SHA_ESPERADO=$(curl -fsSL "https://www.php.net/releases/?json&version=$VERSION" \
    | python3 -I -c 'import json, sys
datos = json.load(sys.stdin)
print(next(f["sha256"] for f in datos["source"] if f["filename"] == sys.argv[1]))' "$ARCHIVO")

echo "→ Descargando $ARCHIVO ..."
curl -fsSL "https://www.php.net/distributions/$ARCHIVO" -o "$DESCARGAS/$ARCHIVO"

echo "→ Verificando integridad ..."
echo "$SHA_ESPERADO  $DESCARGAS/$ARCHIVO" | sha256sum --check --quiet
echo "✓ SHA-256 correcto: $SHA_ESPERADO"

rm -rf "$FUENTES"
mkdir -p "$FUENTES"
tar -xzf "$DESCARGAS/$ARCHIVO" -C "$FUENTES" --strip-components=1

echo "→ Compilando PHP $VERSION (tarda unos minutos) ..."
cd "$FUENTES"
# Solo las extensiones que usa la aplicación. OpenSSL es necesario para que
# mysqlnd se autentique con MySQL 8 (caching_sha2_password). Las rutas de zlib
# y OpenSSL se indican directamente para no depender de pkg-config.
ZLIB_CFLAGS="-I/usr/include" ZLIB_LIBS="-lz" \
OPENSSL_CFLAGS="-I/usr/include" OPENSSL_LIBS="-lssl -lcrypto" \
./configure --quiet \
    --prefix="$DESTINO" \
    --disable-all \
    --enable-cli \
    --disable-cgi \
    --disable-phpdbg \
    --without-pear \
    --enable-pdo \
    --with-pdo-mysql=mysqlnd \
    --enable-session \
    --enable-filter \
    --enable-ctype \
    --enable-tokenizer \
    --with-openssl \
    > "$DEV_DIR/php-configure.log"

make -j"$(nproc)" > "$DEV_DIR/php-make.log" 2>&1
rm -rf "$DESTINO"
make install > "$DEV_DIR/php-install.log" 2>&1

cd "$RAIZ"
rm -rf "$FUENTES"

echo "✓ Instalado: $("$DESTINO/bin/php" -v | head -1)"
