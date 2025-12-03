#!/bin/bash
#
# apply-custom-lifecycle.sh
# Aplica el lifecycle customizado en todas las ubicaciones necesarias de WSO2
#
# WSO2 APIM 4.x tiene el lifecycle en múltiples lugares:
# 1. /repository/resources/lifecycles/ - Backend
# 2. /publisher/build/lifecycles/ - Frontend UI
#
# Uso: ./scripts/apply-custom-lifecycle.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIFECYCLE_FILE="$SCRIPT_DIR/../lifecycle/APILifeCycle.xml"
CONTAINER_NAME="wso2-apim"

echo "════════════════════════════════════════════════════════════"
echo "  Aplicando Lifecycle Customizado en WSO2"
echo "════════════════════════════════════════════════════════════"
echo ""

# Verificar que el archivo existe
if [ ! -f "$LIFECYCLE_FILE" ]; then
    echo "ERROR: No se encuentra $LIFECYCLE_FILE"
    exit 1
fi

# Verificar que el contenedor está corriendo
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "ERROR: El contenedor $CONTAINER_NAME no está corriendo"
    exit 1
fi

echo "[1/4] Copiando lifecycle al contenedor..."
docker cp "$LIFECYCLE_FILE" ${CONTAINER_NAME}:/tmp/APILifeCycle.xml

echo "[2/4] Actualizando backend (/repository/resources/lifecycles/)..."
docker exec ${CONTAINER_NAME} bash -c '
    BACKEND_DIR="/home/wso2carbon/wso2am-4.5.0/repository/resources/lifecycles"

    # Backup si no existe
    if [ ! -f "$BACKEND_DIR/APILifeCycle.xml.original" ]; then
        cp "$BACKEND_DIR/APILifeCycle.xml" "$BACKEND_DIR/APILifeCycle.xml.original" 2>/dev/null || true
    fi

    # Copiar el nuevo
    cp /tmp/APILifeCycle.xml "$BACKEND_DIR/APILifeCycle.xml"
    echo "  ✓ Backend actualizado"
'

echo "[3/4] Actualizando frontend (/publisher/build/lifecycles/)..."
docker exec ${CONTAINER_NAME} bash -c '
    FRONTEND_DIR="/home/wso2carbon/wso2am-4.5.0/repository/deployment/server/webapps/publisher/build/lifecycles"

    # Backup si no existe
    if [ ! -f "$FRONTEND_DIR/APILifeCycle.xml.original" ]; then
        cp "$FRONTEND_DIR/APILifeCycle.xml" "$FRONTEND_DIR/APILifeCycle.xml.original" 2>/dev/null || true
    fi

    # Copiar el nuevo
    cp /tmp/APILifeCycle.xml "$FRONTEND_DIR/APILifeCycle.xml"
    echo "  ✓ Frontend actualizado"
'

echo "[4/4] Limpiando cache del publisher..."
docker exec ${CONTAINER_NAME} bash -c '
    # Limpiar cache si existe
    CACHE_DIR="/home/wso2carbon/wso2am-4.5.0/repository/deployment/server/webapps/publisher/build/.cache"
    if [ -d "$CACHE_DIR" ]; then
        rm -rf "$CACHE_DIR"
        echo "  ✓ Cache limpiado"
    else
        echo "  (sin cache que limpiar)"
    fi
'

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  ✓ Lifecycle aplicado correctamente"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "  IMPORTANTE: Es necesario reiniciar WSO2 para que los"
echo "  cambios surtan efecto completamente."
echo ""
echo "  El botón 'Register UAT' aparecerá en APIs con estado"
echo "  'Published' después de reiniciar."
echo ""

read -p "  ¿Reiniciar WSO2 ahora? (y/N): " confirm

if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
    echo ""
    echo "  Reiniciando WSO2 APIM..."
    docker restart ${CONTAINER_NAME}
    echo ""
    echo "  Esperando a que WSO2 esté listo (esto tarda ~2-3 minutos)..."
    "$SCRIPT_DIR/wait-for-apim.sh"
    echo ""
    echo "  ✓ WSO2 reiniciado y listo"
    echo ""
    echo "  Ahora puedes ir a https://localhost:9443/publisher"
    echo "  y verificar el botón 'Register UAT' en una API Published."
else
    echo ""
    echo "  OK. Ejecuta 'docker restart wso2-apim' cuando quieras aplicar."
fi
