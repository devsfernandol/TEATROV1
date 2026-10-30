#!/usr/bin/env bash
# Genera el ZIP de entrega a partir del último commit (no incluye cambios sin
# confirmar). Deja fuera lo marcado con export-ignore en .gitattributes.
#
# Uso: dev/empaquetar.sh [referencia]   (por defecto HEAD)

set -euo pipefail
source "$(dirname "$0")/entorno.sh"

REF="${1:-HEAD}"
SALIDA="$RAIZ/dist/teatro.zip"

cd "$RAIZ"
if [[ -n "$(git status --porcelain)" ]]; then
    echo "⚠ Hay cambios sin confirmar: no se incluirán en el paquete." >&2
fi

mkdir -p "$RAIZ/dist"
git archive --format=zip --prefix=teatro/ -o "$SALIDA" "$REF"

echo "✓ Paquete generado: dist/teatro.zip ($(git rev-parse --short "$REF"))"
unzip -l "$SALIDA" | awk 'NR > 3 && $4 != "" { print "   " $4 }' | head -n -1
