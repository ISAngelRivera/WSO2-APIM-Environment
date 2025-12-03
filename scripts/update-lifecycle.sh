#!/bin/bash
#
# update-lifecycle.sh
# Actualiza el lifecycle de APIs en el registry de WSO2
#
# En WSO2 APIM 4.x, el lifecycle se almacena en el registry interno.
# Este script lo actualiza usando la API de administración.
#
# Uso: ./scripts/update-lifecycle.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIFECYCLE_FILE="$SCRIPT_DIR/../lifecycle/APILifeCycle.xml"

echo "════════════════════════════════════════════════════════════"
echo "  Actualizando API Lifecycle en WSO2"
echo "════════════════════════════════════════════════════════════"
echo ""

# Verificar que el archivo existe
if [ ! -f "$LIFECYCLE_FILE" ]; then
    echo "ERROR: No se encuentra $LIFECYCLE_FILE"
    exit 1
fi

echo "[1/3] Leyendo lifecycle customizado..."
LIFECYCLE_CONTENT=$(cat "$LIFECYCLE_FILE")

echo "[2/3] Copiando lifecycle al contenedor..."
docker cp "$LIFECYCLE_FILE" wso2-apim:/tmp/APILifeCycle.xml

echo "[3/3] Actualizando lifecycle en el registry..."

# El lifecycle en WSO2 4.x se puede actualizar copiando al directorio correcto
# y reiniciando, o usando la consola de Carbon

# Método 1: Copiar directamente al directorio de lifecycles del registry
docker exec wso2-apim bash -c '
    # El lifecycle debe estar en el directorio de configuración
    LIFECYCLE_DIR="/home/wso2carbon/wso2am-4.5.0/repository/resources/lifecycles"

    # Backup del original
    if [ -f "$LIFECYCLE_DIR/APILifeCycle.xml.bak" ]; then
        echo "  Backup ya existe"
    else
        cp "$LIFECYCLE_DIR/APILifeCycle.xml" "$LIFECYCLE_DIR/APILifeCycle.xml.bak" 2>/dev/null || true
    fi

    # Copiar el nuevo
    cp /tmp/APILifeCycle.xml "$LIFECYCLE_DIR/APILifeCycle.xml"

    echo "  ✓ Archivo copiado"
'

echo ""
echo "  ⚠ IMPORTANTE: Para que el cambio surta efecto, es necesario"
echo "    reiniciar el contenedor de WSO2:"
echo ""
echo "    docker restart wso2-apim"
echo ""
echo "    Después de reiniciar, espera ~2 minutos y las nuevas APIs"
echo "    tendrán el lifecycle customizado."
echo ""
echo "    NOTA: Las APIs ya creadas mantendrán el lifecycle anterior."
echo "    Solo las nuevas APIs usarán el nuevo lifecycle."
echo ""

read -p "  ¿Reiniciar ahora? (y/N): " confirm

if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
    echo ""
    echo "  Reiniciando WSO2 APIM..."
    docker restart wso2-apim
    echo ""
    echo "  Esperando a que WSO2 esté listo..."
    sleep 10
    "$SCRIPT_DIR/wait-for-apim.sh"
else
    echo ""
    echo "  OK. Recuerda reiniciar manualmente cuando quieras aplicar los cambios."
fi
