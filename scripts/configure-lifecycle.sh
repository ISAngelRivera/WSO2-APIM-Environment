#!/bin/bash
#
# configure-lifecycle.sh
# Configura el lifecycle estándar en WSO2 APIM vía Admin API
#
# Este script configura el lifecycle estándar de WSO2.
# El registro en UAT se maneja a través del componente React UATRegistration,
# NO a través del lifecycle.
#
# Uso: ./scripts/configure-lifecycle.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_NAME="wso2-apim"

echo "════════════════════════════════════════════════════════════"
echo "  Configurando Lifecycle en WSO2 APIM"
echo "════════════════════════════════════════════════════════════"
echo ""

# Verificar que WSO2 está corriendo
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "ERROR: El contenedor $CONTAINER_NAME no está corriendo"
    exit 1
fi

echo "[1/3] Registrando cliente OAuth..."

# Registrar cliente OAuth
CLIENT_RESPONSE=$(curl -s -k -X POST \
  "https://localhost:9443/client-registration/v0.17/register" \
  -H "Authorization: Basic YWRtaW46YWRtaW4=" \
  -H "Content-Type: application/json" \
  -d '{"callbackUrl":"https://localhost","clientName":"lifecycle_config","owner":"admin","grantType":"password","saasApp":true}')

CLIENT_ID=$(echo "$CLIENT_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['clientId'])")
CLIENT_SECRET=$(echo "$CLIENT_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['clientSecret'])")

# Obtener token
TOKEN=$(curl -s -k -X POST \
  "https://localhost:9443/oauth2/token" \
  -u "$CLIENT_ID:$CLIENT_SECRET" \
  -d "grant_type=password&username=admin&password=admin&scope=apim:admin apim:tenantInfo" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

echo "  ✓ Cliente OAuth registrado"

echo ""
echo "[2/3] Obteniendo configuración actual..."

# Obtener config actual
CURRENT_CONFIG=$(curl -s -k -X GET \
  "https://localhost:9443/api/am/admin/v4/tenant-config" \
  -H "Authorization: Bearer $TOKEN")

echo "  ✓ Configuración obtenida"

echo ""
echo "[3/3] Configurando lifecycle estándar..."

# Añadir LifeCycle estándar (sin Register UAT)
NEW_CONFIG=$(echo "$CURRENT_CONFIG" | python3 -c "
import sys, json

config = json.load(sys.stdin)

# Lifecycle estándar de WSO2 - SIN Register UAT
# El registro en UAT se hace via componente React UATRegistration
config['LifeCycle'] = {
    'States': [
        {
            'State': 'Created',
            'Transitions': [
                {'Event': 'Publish', 'Target': 'Published'},
                {'Event': 'Deploy as a Prototype', 'Target': 'Prototyped'}
            ],
            'CheckItems': [
                'Deprecate old versions after publishing the API',
                'Requires re-subscription when publishing the API'
            ]
        },
        {
            'State': 'Prototyped',
            'Transitions': [
                {'Event': 'Publish', 'Target': 'Published'},
                {'Event': 'Demote to Created', 'Target': 'Created'},
                {'Event': 'Deploy as a Prototype', 'Target': 'Prototyped'}
            ],
            'CheckItems': [
                'Deprecate old versions after publishing the API',
                'Requires re-subscription when publishing the API'
            ]
        },
        {
            'State': 'Published',
            'Transitions': [
                {'Event': 'Block', 'Target': 'Blocked'},
                {'Event': 'Deploy as a Prototype', 'Target': 'Prototyped'},
                {'Event': 'Demote to Created', 'Target': 'Created'},
                {'Event': 'Deprecate', 'Target': 'Deprecated'},
                {'Event': 'Publish', 'Target': 'Published'}
            ]
        },
        {
            'State': 'Blocked',
            'Transitions': [
                {'Event': 'Deprecate', 'Target': 'Deprecated'},
                {'Event': 'Re-Publish', 'Target': 'Published'}
            ]
        },
        {
            'State': 'Deprecated',
            'Transitions': [
                {'Event': 'Retire', 'Target': 'Retired'}
            ]
        },
        {
            'State': 'Retired'
        }
    ]
}

print(json.dumps(config))
")

# Actualizar tenant-config
HTTP_CODE=$(curl -s -k -X PUT \
  "https://localhost:9443/api/am/admin/v4/tenant-config" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$NEW_CONFIG" \
  -o /dev/null -w "%{http_code}")

if [ "$HTTP_CODE" == "200" ]; then
    echo "  ✓ Tenant-config actualizado"
else
    echo "  ✗ Error actualizando tenant-config (HTTP $HTTP_CODE)"
    exit 1
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  ✓ Lifecycle configurado correctamente!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "  Estados disponibles: Created → Published → Deprecated → Retired"
echo ""
echo "  NOTA: El registro en UAT se realiza a través del componente"
echo "        'Registro en UAT' en la página de Lifecycle del Publisher."
echo ""
