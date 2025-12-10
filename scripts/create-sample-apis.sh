#!/bin/bash
# =============================================================================
# Script para crear 10 APIs de prueba en WSO2 APIM
# - 6 APIs apuntan a finanzas-pagos (domain-a)
# - 4 APIs apuntan a rrhh-empleados (domain-b)
# - Cada API tiene el campo 'subdominio' en additionalProperties
# =============================================================================

WSO2_HOST="${WSO2_HOST:-localhost}"
WSO2_PORT="${WSO2_PORT:-9443}"
WSO2_USER="${WSO2_USER:-admin}"
WSO2_PASS="${WSO2_PASS:-admin}"
BASE_URL="https://${WSO2_HOST}:${WSO2_PORT}"

echo "============================================"
echo "  Creando 10 APIs de prueba en WSO2"
echo "  Con campo 'subdominio' configurado"
echo "============================================"
echo "Target: $BASE_URL"
echo ""

# Obtener token OAuth
echo "1. Obteniendo token OAuth..."

CLIENT_RESPONSE=$(curl -sk -X POST \
  -H "Authorization: Basic $(echo -n "${WSO2_USER}:${WSO2_PASS}" | base64)" \
  -H "Content-Type: application/json" \
  -d '{
    "callbackUrl": "https://localhost",
    "clientName": "api_creator_script",
    "owner": "admin",
    "grantType": "client_credentials password refresh_token",
    "saasApp": true
  }' \
  "${BASE_URL}/client-registration/v0.17/register")

CLIENT_ID=$(echo "$CLIENT_RESPONSE" | jq -r '.clientId')
CLIENT_SECRET=$(echo "$CLIENT_RESPONSE" | jq -r '.clientSecret')

if [ "$CLIENT_ID" == "null" ] || [ -z "$CLIENT_ID" ]; then
  echo "ERROR: No se pudo registrar cliente OAuth"
  echo "Response: $CLIENT_RESPONSE"
  exit 1
fi

TOKEN_RESPONSE=$(curl -sk -X POST \
  -H "Authorization: Basic $(echo -n "${CLIENT_ID}:${CLIENT_SECRET}" | base64)" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password&username=${WSO2_USER}&password=${WSO2_PASS}&scope=apim:api_create apim:api_publish apim:api_view" \
  "${BASE_URL}/oauth2/token")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

if [ "$ACCESS_TOKEN" == "null" ] || [ -z "$ACCESS_TOKEN" ]; then
  echo "ERROR: No se pudo obtener token"
  exit 1
fi

echo "   Token obtenido correctamente"
echo ""

# Función para crear API base con subdominio
create_api() {
  local name="$1"
  local version="$2"
  local context="$3"
  local backend="$4"
  local subdominio="$5"
  local description="$6"

  echo "   Creando: $name v$version -> subdominio: $subdominio"

  API_RESPONSE=$(curl -sk -X POST \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"name\": \"$name\",
      \"version\": \"$version\",
      \"context\": \"$context\",
      \"description\": \"$description\",
      \"endpointConfig\": {
        \"endpoint_type\": \"http\",
        \"production_endpoints\": {
          \"url\": \"https://$backend\"
        },
        \"sandbox_endpoints\": {
          \"url\": \"https://sandbox.$backend\"
        }
      },
      \"additionalProperties\": [
        {
          \"name\": \"subdominio\",
          \"value\": \"$subdominio\",
          \"display\": true
        }
      ],
      \"policies\": [\"Unlimited\"],
      \"transport\": [\"http\", \"https\"],
      \"visibility\": \"PUBLIC\",
      \"gatewayType\": \"wso2/synapse\",
      \"type\": \"HTTP\"
    }" \
    "${BASE_URL}/api/am/publisher/v4/apis")

  API_ID=$(echo "$API_RESPONSE" | jq -r '.id')

  if [ "$API_ID" == "null" ] || [ -z "$API_ID" ]; then
    local error=$(echo "$API_RESPONSE" | jq -r '.description // .message // "error desconocido"')
    echo "      WARNING: $error"
    echo ""
    return 1
  fi

  # Añadir OpenAPI básico
  curl -sk -X PUT \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"openapi\": \"3.0.0\",
      \"info\": {
        \"title\": \"$name\",
        \"version\": \"$version\",
        \"description\": \"$description\"
      },
      \"servers\": [{\"url\": \"https://$backend\"}],
      \"paths\": {
        \"/health\": {
          \"get\": {
            \"summary\": \"Health check\",
            \"responses\": {\"200\": {\"description\": \"OK\"}}
          }
        },
        \"/resource\": {
          \"get\": {
            \"summary\": \"Get resource\",
            \"responses\": {\"200\": {\"description\": \"Success\"}}
          },
          \"post\": {
            \"summary\": \"Create resource\",
            \"responses\": {\"201\": {\"description\": \"Created\"}}
          }
        }
      }
    }" \
    "${BASE_URL}/api/am/publisher/v4/apis/${API_ID}/swagger" > /dev/null 2>&1

  # Publicar API
  curl -sk -X POST \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    "${BASE_URL}/api/am/publisher/v4/apis/change-lifecycle?apiId=${API_ID}&action=Publish" > /dev/null 2>&1

  echo "      OK: $API_ID (PUBLISHED)"
  echo "$API_ID"
  return 0
}

# Función para crear nueva versión de una API existente (hereda subdominio)
create_new_version() {
  local source_api_id="$1"
  local new_version="$2"

  echo "   Creando nueva versión: v$new_version desde $source_api_id"

  # Crear nueva versión usando query param (no body)
  NEW_API_RESPONSE=$(curl -sk -X POST \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    "${BASE_URL}/api/am/publisher/v4/apis/copy-api?apiId=${source_api_id}&newVersion=${new_version}")

  NEW_API_ID=$(echo "$NEW_API_RESPONSE" | jq -r '.id')

  if [ "$NEW_API_ID" == "null" ] || [ -z "$NEW_API_ID" ]; then
    local error=$(echo "$NEW_API_RESPONSE" | jq -r '.description // .message // "error desconocido"')
    echo "      WARNING: $error"
    return 1
  fi

  # Publicar nueva versión
  curl -sk -X POST \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    "${BASE_URL}/api/am/publisher/v4/apis/change-lifecycle?apiId=${NEW_API_ID}&action=Publish" > /dev/null 2>&1

  echo "      OK: $NEW_API_ID (PUBLISHED)"
  echo "$NEW_API_ID"
  return 0
}

# Obtener API ID por nombre y versión
get_api_id() {
  local name="$1"
  local version="$2"

  curl -sk -H "Authorization: Bearer $ACCESS_TOKEN" \
    "${BASE_URL}/api/am/publisher/v4/apis?query=name:${name}" | jq -r ".list[] | select(.version==\"$version\") | .id"
}

# =============================================================================
# FINANZAS-PAGOS: 6 APIs
# =============================================================================
DOMAIN_A="api.domain-a.com"
SUBDOM_A="finanzas-pagos"
echo "2. Creando APIs para subdominio: $SUBDOM_A"
echo ""

# CustomerAPI v1.0.0 (base)
CUSTOMER_V1=$(create_api "CustomerAPI" "1.0.0" "/customers" "$DOMAIN_A/customers" "$SUBDOM_A" "API de gestión de clientes")
if [ -z "$CUSTOMER_V1" ] || [ "$CUSTOMER_V1" == "1" ]; then
  CUSTOMER_V1=$(get_api_id "CustomerAPI" "1.0.0")
fi

# CustomerAPI v2.0.0 (nueva versión desde v1)
if [ -n "$CUSTOMER_V1" ]; then
  create_new_version "$CUSTOMER_V1" "2.0.0"
fi

# OrdersAPI v1.0.0 y v2.0.0
ORDERS_V1=$(create_api "OrdersAPI" "1.0.0" "/orders" "$DOMAIN_A/orders" "$SUBDOM_A" "API de gestión de pedidos")
if [ -z "$ORDERS_V1" ] || [ "$ORDERS_V1" == "1" ]; then
  ORDERS_V1=$(get_api_id "OrdersAPI" "1.0.0")
fi
if [ -n "$ORDERS_V1" ]; then
  create_new_version "$ORDERS_V1" "2.0.0"
fi

# ProductCatalog v3.1.0
create_api "ProductCatalog" "3.1.0" "/catalog" "$DOMAIN_A/catalog" "$SUBDOM_A" "Catálogo de productos"

# PaymentsAPI v1.2.0
create_api "PaymentsAPI" "1.2.0" "/payments" "$DOMAIN_A/payments" "$SUBDOM_A" "API de procesamiento de pagos"

echo ""

# =============================================================================
# RRHH-EMPLEADOS: 4 APIs
# =============================================================================
DOMAIN_B="api.domain-b.com"
SUBDOM_B="rrhh-empleados"
echo "3. Creando APIs para subdominio: $SUBDOM_B"
echo ""

# InventoryAPI v2.0.0
create_api "InventoryAPI" "2.0.0" "/inventory" "$DOMAIN_B/inventory" "$SUBDOM_B" "Control de inventario"

# ShippingAPI v1.5.0 y v2.0.0
SHIPPING_V1=$(create_api "ShippingAPI" "1.5.0" "/shipping" "$DOMAIN_B/shipping" "$SUBDOM_B" "API de envíos y logística")
if [ -z "$SHIPPING_V1" ] || [ "$SHIPPING_V1" == "1" ]; then
  SHIPPING_V1=$(get_api_id "ShippingAPI" "1.5.0")
fi
if [ -n "$SHIPPING_V1" ]; then
  create_new_version "$SHIPPING_V1" "2.0.0"
fi

# AnalyticsAPI v1.0.0
create_api "AnalyticsAPI" "1.0.0" "/analytics" "$DOMAIN_B/analytics" "$SUBDOM_B" "API de análisis y métricas"

echo ""
echo "============================================"
echo "  Proceso completado"
echo "============================================"
echo ""

# Listar APIs creadas
echo "4. Verificando APIs en el sistema..."
echo ""

# Mostrar tabla con subdominio
echo "APIs disponibles:"
echo "--------------------------------------------------------------------------------"
printf "%-20s %-10s %-15s %-20s\n" "API" "VERSION" "CONTEXT" "SUBDOMINIO"
echo "--------------------------------------------------------------------------------"

curl -sk -H "Authorization: Bearer $ACCESS_TOKEN" \
  "${BASE_URL}/api/am/publisher/v4/apis?limit=25" | jq -r '.list[] | "\(.name)|\(.version)|\(.context)"' | sort | while IFS='|' read -r name version context; do

  # Obtener subdominio de la API
  API_ID=$(curl -sk -H "Authorization: Bearer $ACCESS_TOKEN" \
    "${BASE_URL}/api/am/publisher/v4/apis?query=name:${name}" | jq -r ".list[] | select(.version==\"$version\") | .id")

  if [ -n "$API_ID" ]; then
    SUBDOM=$(curl -sk -H "Authorization: Bearer $ACCESS_TOKEN" \
      "${BASE_URL}/api/am/publisher/v4/apis/${API_ID}" | jq -r '.additionalProperties[] | select(.name=="subdominio") | .value // "N/A"')
    [ -z "$SUBDOM" ] && SUBDOM="N/A"
  else
    SUBDOM="N/A"
  fi

  printf "%-20s %-10s %-15s %-20s\n" "$name" "$version" "$context" "$SUBDOM"
done

echo "--------------------------------------------------------------------------------"
echo ""
