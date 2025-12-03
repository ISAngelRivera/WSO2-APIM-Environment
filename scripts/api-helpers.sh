#!/bin/bash
#
# api-helpers.sh
# Funciones auxiliares para crear y gestionar APIs en WSO2 APIM
#
# Uso: source ./scripts/api-helpers.sh

APIM_URL="https://localhost:9443"
ADMIN_USER="admin"
ADMIN_PASS="admin"
ACCESS_TOKEN=""

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ══════════════════════════════════════════════════════════════
# get_access_token
# Obtiene token OAuth2 para las APIs de Publisher
# ══════════════════════════════════════════════════════════════
get_access_token() {
    # Registrar cliente OAuth
    local client_response=$(curl -k -s -X POST \
        -u "$ADMIN_USER:$ADMIN_PASS" \
        -H "Content-Type: application/json" \
        -d '{
            "callbackUrl": "https://localhost",
            "clientName": "apim_script_client_'$(date +%s)'",
            "owner": "admin",
            "grantType": "password refresh_token",
            "saasApp": true
        }' \
        "$APIM_URL/client-registration/v0.17/register" 2>/dev/null)

    local client_id=$(echo "$client_response" | grep -o '"clientId":"[^"]*"' | cut -d'"' -f4)
    local client_secret=$(echo "$client_response" | grep -o '"clientSecret":"[^"]*"' | cut -d'"' -f4)

    if [ -z "$client_id" ] || [ -z "$client_secret" ]; then
        echo -e "${YELLOW}  ⚠ No se pudo registrar cliente OAuth, usando Basic Auth${NC}"
        ACCESS_TOKEN=""
        return
    fi

    # Obtener token
    local token_response=$(curl -k -s -X POST \
        -u "$client_id:$client_secret" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=password&username=$ADMIN_USER&password=$ADMIN_PASS&scope=apim:api_create apim:api_publish apim:api_view apim:api_delete" \
        "$APIM_URL/oauth2/token" 2>/dev/null)

    ACCESS_TOKEN=$(echo "$token_response" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

    if [ -z "$ACCESS_TOKEN" ]; then
        echo -e "${YELLOW}  ⚠ No se pudo obtener token, usando Basic Auth${NC}"
        ACCESS_TOKEN=""
    fi
}

# ══════════════════════════════════════════════════════════════
# get_auth_header
# Devuelve el header de autorización apropiado
# ══════════════════════════════════════════════════════════════
get_auth_header() {
    if [ -n "$ACCESS_TOKEN" ]; then
        echo "Bearer $ACCESS_TOKEN"
    else
        echo "Basic $(echo -n "$ADMIN_USER:$ADMIN_PASS" | base64)"
    fi
}

# ══════════════════════════════════════════════════════════════
# create_api
# Crea un nuevo API y lo publica
#
# Params:
#   $1 - name
#   $2 - version
#   $3 - context
#   $4 - domain
#   $5 - subdomain
#   $6 - description
#   $7 - operations (JSON array)
# ══════════════════════════════════════════════════════════════
create_api() {
    local name="$1"
    local version="$2"
    local context="$3"
    local domain="$4"
    local subdomain="$5"
    local description="$6"
    local operations="$7"

    local auth_header=$(get_auth_header)

    # Verificar si ya existe
    local existing=$(curl -k -s \
        -H "Authorization: $auth_header" \
        "$APIM_URL/api/am/publisher/v4/apis?query=name:$name%20version:$version" 2>/dev/null)

    local existing_id=$(echo "$existing" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

    if [ -n "$existing_id" ]; then
        echo -e "        ${YELLOW}ℹ $name v$version ya existe (ID: ${existing_id:0:8}...)${NC}"
        return 0
    fi

    # Crear API
    local payload=$(cat <<EOF
{
    "name": "$name",
    "version": "$version",
    "context": "$context",
    "description": "$description",
    "endpointConfig": {
        "endpoint_type": "http",
        "production_endpoints": {
            "url": "https://httpbin.org"
        },
        "sandbox_endpoints": {
            "url": "https://httpbin.org"
        }
    },
    "operations": $operations,
    "policies": ["Unlimited"],
    "additionalProperties": [
        {"name": "Domain", "value": "$domain", "display": true},
        {"name": "Subdomain", "value": "$subdomain", "display": true},
        {"name": "Owner", "value": "team-$subdomain@example.com", "display": true}
    ],
    "tags": ["$domain", "$subdomain", "APIOps"]
}
EOF
)

    local create_response=$(curl -k -s -X POST \
        -H "Authorization: $auth_header" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$APIM_URL/api/am/publisher/v4/apis" 2>/dev/null)

    local api_id=$(echo "$create_response" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

    if [ -z "$api_id" ]; then
        echo -e "        ${RED}✗ Error creando $name v$version${NC}"
        echo "$create_response" | head -c 200
        return 1
    fi

    # Publicar API
    curl -k -s -X POST \
        -H "Authorization: $auth_header" \
        "$APIM_URL/api/am/publisher/v4/apis/change-lifecycle?apiId=$api_id&action=Publish" > /dev/null 2>&1

    echo -e "        ${GREEN}✓ $name v$version creado y publicado${NC}"

    # Pequeño delay para que WSO2 indexe el API
    sleep 2
}

# ══════════════════════════════════════════════════════════════
# create_api_version
# Crea una nueva versión de un API existente (ej: 1.0.0 → 2.0.0)
#
# Params:
#   $1 - name (API existente)
#   $2 - source_version (versión origen)
#   $3 - new_version (nueva versión)
# ══════════════════════════════════════════════════════════════
create_api_version() {
    local name="$1"
    local source_version="$2"
    local new_version="$3"

    local auth_header=$(get_auth_header)

    # Obtener ID del API origen
    local api_response=$(curl -k -s \
        -H "Authorization: $auth_header" \
        "$APIM_URL/api/am/publisher/v4/apis?query=name:$name" 2>/dev/null)

    local api_id=""
    if command -v jq &> /dev/null; then
        api_id=$(echo "$api_response" | jq -r ".list[] | select(.name==\"$name\" and .version==\"$source_version\") | .id" 2>/dev/null | head -1)
    fi

    if [ -z "$api_id" ] || [ "$api_id" = "null" ]; then
        echo -e "        ${RED}✗ API $name v$source_version no encontrado para copiar${NC}"
        return 1
    fi

    # Crear nueva versión usando copy-api
    local copy_response=$(curl -k -s -X POST \
        -H "Authorization: $auth_header" \
        -H "Content-Type: application/json" \
        "$APIM_URL/api/am/publisher/v4/apis/copy-api?apiId=$api_id&newVersion=$new_version" 2>/dev/null)

    local new_api_id=$(echo "$copy_response" | jq -r '.id' 2>/dev/null)

    if [ -z "$new_api_id" ] || [ "$new_api_id" = "null" ]; then
        echo -e "        ${RED}✗ Error creando $name v$new_version${NC}"
        return 1
    fi

    # Publicar la nueva versión
    curl -k -s -X POST \
        -H "Authorization: $auth_header" \
        "$APIM_URL/api/am/publisher/v4/apis/change-lifecycle?apiId=$new_api_id&action=Publish" > /dev/null 2>&1

    echo -e "        ${GREEN}✓ $name v$new_version creado (copiado de v$source_version)${NC}"
    sleep 2
}

# ══════════════════════════════════════════════════════════════
# create_revision
# Crea una nueva revisión de un API existente
#
# Params:
#   $1 - name
#   $2 - version
#   $3 - description
# ══════════════════════════════════════════════════════════════
create_revision() {
    local name="$1"
    local version="$2"
    local description="$3"

    local auth_header=$(get_auth_header)

    # Obtener ID del API usando jq si está disponible, sino con grep
    local api_response=$(curl -k -s \
        -H "Authorization: $auth_header" \
        "$APIM_URL/api/am/publisher/v4/apis?query=name:$name" 2>/dev/null)

    local api_id=""
    if command -v jq &> /dev/null; then
        api_id=$(echo "$api_response" | jq -r ".list[] | select(.name==\"$name\" and .version==\"$version\") | .id" 2>/dev/null | head -1)
    else
        api_id=$(echo "$api_response" | sed 's/,/\n/g' | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    fi

    if [ -z "$api_id" ] || [ "$api_id" = "null" ]; then
        echo -e "        ${RED}✗ API $name v$version no encontrado${NC}"
        return 1
    fi

    # Crear revisión
    local revision_payload=$(cat <<EOF
{
    "description": "$description"
}
EOF
)

    local revision_response=$(curl -k -s -X POST \
        -H "Authorization: $auth_header" \
        -H "Content-Type: application/json" \
        -d "$revision_payload" \
        "$APIM_URL/api/am/publisher/v4/apis/$api_id/revisions" 2>/dev/null)

    local revision_id=$(echo "$revision_response" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

    if [ -z "$revision_id" ]; then
        # Puede ser que ya haya alcanzado el límite de revisiones
        echo -e "        ${YELLOW}ℹ No se pudo crear revisión (posible límite alcanzado)${NC}"
        return 0
    fi

    # Desplegar revisión en gateway
    local deploy_payload='[{"name": "Default", "vhost": "localhost"}]'

    curl -k -s -X POST \
        -H "Authorization: $auth_header" \
        -H "Content-Type: application/json" \
        -d "$deploy_payload" \
        "$APIM_URL/api/am/publisher/v4/apis/$api_id/revisions/$revision_id/deploy" > /dev/null 2>&1

    echo -e "        ${GREEN}✓ Revisión creada: $description${NC}"
}

# ══════════════════════════════════════════════════════════════
# deprecate_api
# Marca un API como deprecated
#
# Params:
#   $1 - name
#   $2 - version
# ══════════════════════════════════════════════════════════════
deprecate_api() {
    local name="$1"
    local version="$2"

    local auth_header=$(get_auth_header)

    # Obtener ID del API usando jq si está disponible
    local api_response=$(curl -k -s \
        -H "Authorization: $auth_header" \
        "$APIM_URL/api/am/publisher/v4/apis?query=name:$name" 2>/dev/null)

    local api_id=""
    if command -v jq &> /dev/null; then
        api_id=$(echo "$api_response" | jq -r ".list[] | select(.name==\"$name\" and .version==\"$version\") | .id" 2>/dev/null | head -1)
    else
        api_id=$(echo "$api_response" | sed 's/,/\n/g' | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    fi

    if [ -z "$api_id" ] || [ "$api_id" = "null" ]; then
        echo -e "        ${RED}✗ API $name v$version no encontrado${NC}"
        return 1
    fi

    # Deprecar
    curl -k -s -X POST \
        -H "Authorization: $auth_header" \
        "$APIM_URL/api/am/publisher/v4/apis/change-lifecycle?apiId=$api_id&action=Deprecate" > /dev/null 2>&1

    echo -e "        ${YELLOW}⚠ $name v$version marcado como DEPRECATED${NC}"
}

# ══════════════════════════════════════════════════════════════
# list_apis
# Lista todas las APIs
# ══════════════════════════════════════════════════════════════
list_apis() {
    local auth_header=$(get_auth_header)

    curl -k -s \
        -H "Authorization: $auth_header" \
        "$APIM_URL/api/am/publisher/v4/apis?limit=100" 2>/dev/null | \
        grep -o '"name":"[^"]*"[^}]*"version":"[^"]*"[^}]*"lifeCycleStatus":"[^"]*"' | \
        while read line; do
            local name=$(echo "$line" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
            local version=$(echo "$line" | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
            local status=$(echo "$line" | grep -o '"lifeCycleStatus":"[^"]*"' | cut -d'"' -f4)
            echo "  $name v$version [$status]"
        done
}
