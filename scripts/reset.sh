#!/bin/bash
#
# reset.sh
# Elimina TODOS los datos y reinicia desde cero
#
# Uso: ./scripts/reset.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo "════════════════════════════════════════════════════════════"
echo "  RESET COMPLETO - WSO2 API Manager"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "  ⚠ Esto eliminará TODOS los datos:"
echo "    - APIs creadas"
echo "    - Configuraciones"
echo "    - Logs"
echo ""
read -p "  ¿Continuar? (y/N): " confirm

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "  Cancelado."
    exit 0
fi

echo ""
echo "  Deteniendo contenedores..."
docker compose down

echo "  Eliminando volúmenes..."
docker volume rm wso2-apim-data wso2-apim-registry wso2-apim-logs 2>/dev/null || true

echo "  Reiniciando..."
docker compose up -d

echo ""
echo "  ✓ Reset completado"
echo ""
echo "  Ejecuta cuando APIM esté listo:"
echo "    ./scripts/setup-all.sh"
