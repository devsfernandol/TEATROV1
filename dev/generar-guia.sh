#!/usr/bin/env bash
# Genera GUIA-INSTALACION.pdf (se incluye en la entrega) a partir de dev/guia/guia.html,
# imprimiéndola con Chrome o Edge en modo headless.
#
# Uso: dev/generar-guia.sh
# En WSL usa el Chrome o el Edge de Windows; en Linux, chromium o google-chrome.

set -euo pipefail
source "$(dirname "$0")/entorno.sh"

ORIGEN="$RAIZ/dev/guia/guia.html"
DESTINO="$RAIZ/GUIA-INSTALACION.pdf"

for candidato in chromium chromium-browser google-chrome \
    "/mnt/c/Program Files/Google/Chrome/Application/chrome.exe" \
    "/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"; do
    if command -v "$candidato" >/dev/null 2>&1 || [[ -x "$candidato" ]]; then
        NAVEGADOR="$candidato"
        break
    fi
done
[[ -n "${NAVEGADOR:-}" ]] || { echo "✗ No se encontró Chrome, Chromium ni Edge" >&2; exit 1; }

if [[ "$NAVEGADOR" == /mnt/* ]]; then
    # Un navegador de Windows necesita rutas de Windows: se trabaja en su carpeta temporal.
    TEMP_WIN=$(cmd.exe /c 'echo %TEMP%' 2>/dev/null | tr -d '\r')
    TEMP_WSL=$(wslpath "$TEMP_WIN")/teatro-guia
    mkdir -p "$TEMP_WSL"
    cp "$ORIGEN" "$TEMP_WSL/guia.html"
    "$NAVEGADOR" --headless --disable-gpu --no-pdf-header-footer \
        --print-to-pdf="$TEMP_WIN\\teatro-guia\\guia.pdf" \
        "file:///$(wslpath -m "$TEMP_WSL/guia.html")" >/dev/null 2>&1
    cp "$TEMP_WSL/guia.pdf" "$DESTINO"
    rm -rf "$TEMP_WSL"
else
    "$NAVEGADOR" --headless --disable-gpu --no-pdf-header-footer \
        --print-to-pdf="$DESTINO" "file://$ORIGEN" >/dev/null 2>&1
fi

echo "✓ Guía generada: GUIA-INSTALACION.pdf ($(du -k "$DESTINO" | cut -f1) KB)"
