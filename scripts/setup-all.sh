#!/bin/bash
#
# setup-all.sh
# Ejecuta todos los scripts de configuración en orden
#
# Uso: ./scripts/setup-all.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo "════════════════════════════════════════════════════════════"
echo "  WSO2 APIM - Configuración Inicial APIOps"
echo "════════════════════════════════════════════════════════════"
echo ""

# 1. Esperar a que APIM esté listo
echo "[1/3] Verificando que APIM esté listo..."
./scripts/wait-for-apim.sh

# 2. Verificar lifecycle
echo ""
echo "[2/3] Verificando lifecycle customizado..."
./scripts/verify-lifecycle.sh

# 3. Crear APIs de prueba
echo ""
echo "[3/3] Creando set completo de APIs de prueba..."
./scripts/create-all-sample-apis.sh

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  ✓ Configuración completada!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "  Publisher: https://localhost:9443/publisher"
echo "  DevPortal: https://localhost:9443/devportal"
echo "  Carbon:    https://localhost:9443/carbon"
echo ""
echo "  Credenciales: admin / admin"
echo ""
