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

echo "✓ Paquete generado: dist/teatro.zip ($(git rev-parse --short "$REF^{commit}"))"
python3 -c 'import sys, zipfile; [print("   " + n) for n in zipfile.ZipFile(sys.argv[1]).namelist() if not n.endswith("/")]' "$SALIDA"
