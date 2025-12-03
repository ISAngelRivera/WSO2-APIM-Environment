#!/bin/bash
#
# verify-lifecycle.sh
# Verifica que el lifecycle customizado esté cargado correctamente
#
# Uso: ./scripts/verify-lifecycle.sh

set -e

echo "Verificando lifecycle customizado..."

# Verificar que el archivo existe en el contenedor
if docker exec wso2-apim test -f /home/wso2carbon/wso2am-4.5.0/repository/resources/lifecycles/APILifeCycle.xml; then
    echo "  ✓ Archivo APILifeCycle.xml presente"
else
    echo "  ✗ ERROR: APILifeCycle.xml no encontrado en el contenedor"
    exit 1
fi

# Verificar que contiene nuestros estados custom
if docker exec wso2-apim grep -q "Register UAT" /home/wso2carbon/wso2am-4.5.0/repository/resources/lifecycles/APILifeCycle.xml; then
    echo "  ✓ Estado 'Register UAT' encontrado"
else
    echo "  ✗ ERROR: Estado 'Register UAT' no encontrado"
    exit 1
fi

if docker exec wso2-apim grep -q "Registered UAT" /home/wso2carbon/wso2am-4.5.0/repository/resources/lifecycles/APILifeCycle.xml; then
    echo "  ✓ Estado 'Registered UAT' encontrado"
else
    echo "  ✗ ERROR: Estado 'Registered UAT' no encontrado"
    exit 1
fi

echo ""
echo "  ✓ Lifecycle customizado verificado correctamente"
echo ""
echo "  Estados disponibles:"
echo "    Created → Published → Registering UAT → Registered UAT"
echo "                           → Promoting NFT → Registered NFT"
echo "                           → Promoting PRO → Production"
