#!/bin/bash
#
# stop.sh
# Detiene el entorno WSO2 APIM (mantiene los datos)
#
# Uso: ./scripts/stop.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo "Deteniendo WSO2 API Manager..."
docker compose down

echo ""
echo "  ✓ Contenedor detenido"
echo "  ℹ Los datos se han preservado en los volúmenes"
echo ""
echo "  Para reiniciar: ./scripts/start.sh"
echo "  Para borrar todo: ./scripts/reset.sh"
