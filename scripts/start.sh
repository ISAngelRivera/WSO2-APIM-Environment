#!/bin/bash
#
# start.sh
# Inicia el entorno WSO2 APIM
#
# Uso: ./scripts/start.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo "════════════════════════════════════════════════════════════"
echo "  Iniciando WSO2 API Manager..."
echo "════════════════════════════════════════════════════════════"

docker compose up -d

echo ""
echo "  Contenedor iniciado. WSO2 tarda ~2-3 minutos en arrancar."
echo ""
echo "  Para ver los logs:"
echo "    docker compose logs -f"
echo ""
echo "  Para verificar cuando esté listo:"
echo "    ./scripts/wait-for-apim.sh"
echo ""
