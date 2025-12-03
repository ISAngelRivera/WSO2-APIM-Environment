#!/bin/bash
#
# create-sample-api.sh
# Crea un API de prueba para validar el flujo APIOps
#
# Uso: ./scripts/create-sample-api.sh

set -e

APIM_URL="https://localhost:9443"
ADMIN_USER="admin"
ADMIN_PASS="admin"

echo "Creando API de prueba (PizzaAPI)..."

# 1. Obtener token de acceso
echo "  Obteniendo token de acceso..."

# Registrar cliente OAuth
CLIENT_RESPONSE=$(curl -k -s -X POST \
    -u "$ADMIN_USER:$ADMIN_PASS" \
    -H "Content-Type: application/json" \
    -d '{
        "callbackUrl": "https://localhost",
        "clientName": "setup_script_client",
        "owner": "admin",
        "grantType": "password refresh_token",
        "saasApp": true
    }' \
    "$APIM_URL/client-registration/v0.17/register")

CLIENT_ID=$(echo "$CLIENT_RESPONSE" | grep -o '"clientId":"[^"]*"' | cut -d'"' -f4)
CLIENT_SECRET=$(echo "$CLIENT_RESPONSE" | grep -o '"clientSecret":"[^"]*"' | cut -d'"' -f4)

if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
    echo "  ⚠ No se pudo registrar cliente OAuth, intentando con token básico..."
    # Usar autenticación básica como fallback
    AUTH_HEADER="Basic $(echo -n "$ADMIN_USER:$ADMIN_PASS" | base64)"
else
    # Obtener token
    TOKEN_RESPONSE=$(curl -k -s -X POST \
        -u "$CLIENT_ID:$CLIENT_SECRET" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=password&username=$ADMIN_USER&password=$ADMIN_PASS&scope=apim:api_create apim:api_publish apim:api_view" \
        "$APIM_URL/oauth2/token")

    ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

    if [ -z "$ACCESS_TOKEN" ]; then
        echo "  ⚠ No se pudo obtener token, usando autenticación básica..."
        AUTH_HEADER="Basic $(echo -n "$ADMIN_USER:$ADMIN_PASS" | base64)"
    else
        AUTH_HEADER="Bearer $ACCESS_TOKEN"
    fi
fi

# 2. Crear API
echo "  Creando PizzaAPI v1.0.0..."

API_PAYLOAD='{
    "name": "PizzaAPI",
    "version": "1.0.0",
    "context": "/pizza",
    "description": "API de prueba para validar flujo APIOps - Dominio: Informatica, Subdominio: DevOps",
    "endpointConfig": {
        "endpoint_type": "http",
        "production_endpoints": {
            "url": "https://httpbin.org"
        },
        "sandbox_endpoints": {
            "url": "https://httpbin.org"
        }
    },
    "operations": [
        {
            "target": "/menu",
            "verb": "GET"
        },
        {
            "target": "/order",
            "verb": "POST"
        },
        {
            "target": "/order/{orderId}",
            "verb": "GET"
        }
    ],
    "policies": ["Unlimited"],
    "additionalProperties": [
        {
            "name": "Domain",
            "value": "Informatica",
            "display": true
        },
        {
            "name": "Subdomain",
            "value": "DevOps",
            "display": true
        },
        {
            "name": "Owner",
            "value": "angel.rivera@example.com",
            "display": true
        }
    ]
}'

CREATE_RESPONSE=$(curl -k -s -X POST \
    -H "Authorization: $AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d "$API_PAYLOAD" \
    "$APIM_URL/api/am/publisher/v4/apis")

API_ID=$(echo "$CREATE_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$API_ID" ]; then
    # Verificar si ya existe
    EXISTING=$(curl -k -s \
        -H "Authorization: $AUTH_HEADER" \
        "$APIM_URL/api/am/publisher/v4/apis?query=name:PizzaAPI")

    EXISTING_ID=$(echo "$EXISTING" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

    if [ -n "$EXISTING_ID" ]; then
        echo "  ℹ PizzaAPI ya existe (ID: $EXISTING_ID)"
        API_ID=$EXISTING_ID
    else
        echo "  ⚠ No se pudo crear PizzaAPI. Respuesta:"
        echo "$CREATE_RESPONSE" | head -c 500
        echo ""
        echo "  Puedes crear el API manualmente desde el Publisher."
        exit 0
    fi
else
    echo "  ✓ PizzaAPI creada (ID: $API_ID)"
fi

# 3. Publicar API (cambiar lifecycle a Published)
echo "  Publicando API..."

PUBLISH_RESPONSE=$(curl -k -s -X POST \
    -H "Authorization: $AUTH_HEADER" \
    "$APIM_URL/api/am/publisher/v4/apis/change-lifecycle?apiId=$API_ID&action=Publish")

if echo "$PUBLISH_RESPONSE" | grep -q "error\|Error"; then
    # Puede que ya esté publicada
    echo "  ℹ API posiblemente ya publicada"
else
    echo "  ✓ API publicada"
fi

echo ""
echo "  ✓ PizzaAPI lista para probar"
echo ""
echo "  Próximo paso:"
echo "    1. Abre https://localhost:9443/publisher"
echo "    2. Busca 'PizzaAPI'"
echo "    3. Ve a 'Lifecycle' y verás el botón 'Register UAT'"
