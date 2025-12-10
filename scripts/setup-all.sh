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
echo "[1/5] Verificando que APIM esté listo..."
./scripts/wait-for-apim.sh

# 2. Crear usuarios de prueba (dev1, dev2)
echo ""
echo "[2/5] Creando usuarios de prueba..."
./scripts/create-test-users.sh

# 3. Configurar lifecycle con Register UAT
echo ""
echo "[3/5] Configurando lifecycle customizado..."
./scripts/configure-lifecycle.sh

# 4. Verificar lifecycle
echo ""
echo "[4/5] Verificando lifecycle..."
./scripts/verify-lifecycle.sh

# 5. Crear APIs de prueba (9 APIs en 2 dominios + 1 sin subdominio)
echo ""
echo "[5/5] Creando APIs de prueba..."
./scripts/create-test-apis.sh

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  ✓ Configuración completada!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "  Publisher: https://localhost:9443/publisher"
echo "  DevPortal: https://localhost:9443/devportal"
echo "  Carbon:    https://localhost:9443/carbon"
echo ""
echo "  Credenciales:"
echo "    - admin / admin (administrador)"
echo "    - dev1  / dev1@123 (desarrollador)"
echo "    - dev2  / dev2@123 (desarrollador)"
echo ""
