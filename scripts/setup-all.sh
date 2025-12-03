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
echo "[1/4] Verificando que APIM esté listo..."
./scripts/wait-for-apim.sh

# 2. Configurar lifecycle con Register UAT
echo ""
echo "[2/4] Configurando lifecycle customizado..."
./scripts/configure-lifecycle.sh

# 3. Verificar lifecycle
echo ""
echo "[3/4] Verificando lifecycle..."
./scripts/verify-lifecycle.sh

# 4. Crear APIs de prueba
echo ""
echo "[4/4] Creando set completo de APIs de prueba..."
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
