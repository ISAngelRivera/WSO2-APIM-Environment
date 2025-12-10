#!/bin/bash
# =============================================================================
# Script para crear APIs de prueba después de un reset de volúmenes
# =============================================================================
# Crea:
# - rrhh-empleados: EmployeeAPI v1.0, v2.0, DepartmentAPI, AttendanceAPI
# - finanzas-pagos: PaymentAPI v1.0, v2.0, InvoiceAPI, AccountAPI
# - (sin subdominio): TestAPI v1.0 (para probar validación)
# =============================================================================

echo "=============================================="
echo "  Creando APIs de prueba para APIOps"
echo "=============================================="

# Obtener token OAuth2
echo ""
echo "Obteniendo token de acceso..."

CLIENT_RESP=$(curl -sk -X POST \
  -H "Authorization: Basic YWRtaW46YWRtaW4=" \
  -H "Content-Type: application/json" \
  -d '{"callbackUrl":"https://localhost","clientName":"test_apis_creator_'$(date +%s)'","owner":"admin","grantType":"password","saasApp":true}' \
  "https://localhost:9443/client-registration/v0.17/register")

CID=$(echo "$CLIENT_RESP" | jq -r ".clientId")
CS=$(echo "$CLIENT_RESP" | jq -r ".clientSecret")

if [ "$CID" == "null" ] || [ -z "$CID" ]; then
  echo "ERROR: No se pudo registrar cliente OAuth2"
  echo "$CLIENT_RESP"
  exit 1
fi

TOKEN=$(curl -sk -X POST \
  -H "Authorization: Basic $(echo -n "${CID}:${CS}" | base64)" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password&username=admin&password=admin&scope=apim:api_create apim:api_publish apim:api_view" \
  "https://localhost:9443/oauth2/token" | jq -r ".access_token")

if [ "$TOKEN" == "null" ] || [ -z "$TOKEN" ]; then
  echo "ERROR: No se pudo obtener token"
  exit 1
fi

echo "Token obtenido correctamente"

# Función para crear API y luego añadir subdominio
create_api() {
  local name=$1
  local version=$2
  local context=$3
  local subdominio=$4

  echo ""
  echo "Creando $name v$version (subdominio: ${subdominio:-ninguno})..."

  # Generar UUID simple
  local uuid1=$(cat /dev/urandom | LC_ALL=C tr -dc 'a-f0-9' | head -c 32)
  local uuid2=$(cat /dev/urandom | LC_ALL=C tr -dc 'a-f0-9' | head -c 32)

  # Crear API sin additionalProperties primero
  local api_payload='{
    "name": "'"$name"'",
    "version": "'"$version"'",
    "context": "'"$context"'",
    "policies": ["Unlimited"],
    "endpointConfig": {
      "endpoint_type": "http",
      "production_endpoints": {
        "url": "https://run.mocky.io/v3/'"$uuid1"'"
      },
      "sandbox_endpoints": {
        "url": "https://run.mocky.io/v3/'"$uuid2"'"
      }
    },
    "operations": [
      {"target": "/*", "verb": "GET", "authType": "Application & Application User", "throttlingPolicy": "Unlimited"},
      {"target": "/*", "verb": "POST", "authType": "Application & Application User", "throttlingPolicy": "Unlimited"}
    ]
  }'

  local response=$(curl -sk -X POST \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$api_payload" \
    "https://localhost:9443/api/am/publisher/v4/apis")

  local api_id=$(echo "$response" | jq -r ".id")

  if [ "$api_id" == "null" ] || [ -z "$api_id" ]; then
    echo "  ERROR: $(echo "$response" | jq -r ".description // .message // .")"
    return 1
  fi

  echo "  Creada: $api_id"

  # Si hay subdominio, añadirlo via PUT usando additionalProperties array
  if [ -n "$subdominio" ]; then
    # Obtener la API completa
    local api_data=$(curl -sk -H "Authorization: Bearer $TOKEN" \
      "https://localhost:9443/api/am/publisher/v4/apis/${api_id}")

    # Añadir el subdominio usando additionalProperties (array de objetos)
    local updated_api=$(echo "$api_data" | jq '.additionalProperties = [{"name": "subdominio", "value": "'"$subdominio"'", "display": true}]')

    # Actualizar la API
    local update_resp=$(curl -sk -X PUT \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d "$updated_api" \
      "https://localhost:9443/api/am/publisher/v4/apis/${api_id}")

    # Verificar que se guardó
    local saved=$(echo "$update_resp" | jq -r '.additionalProperties[0].value // empty')
    if [ "$saved" == "$subdominio" ]; then
      echo "  Subdominio configurado: $subdominio"
    else
      echo "  WARN: Subdominio no se guardó correctamente"
    fi
  fi

  # Publicar
  curl -sk -X POST \
    -H "Authorization: Bearer $TOKEN" \
    "https://localhost:9443/api/am/publisher/v4/apis/change-lifecycle?apiId=${api_id}&action=Publish" > /dev/null 2>&1

  echo "  Publicada"

  # Devolver el ID
  echo "$api_id" > /tmp/last_api_id.txt
}

# Función para crear versión 2.0 de una API
create_api_v2() {
  local source_id=$1
  local name=$2

  echo ""
  echo "Creando $name v2.0.0..."

  local response=$(curl -sk -X POST \
    -H "Authorization: Bearer $TOKEN" \
    "https://localhost:9443/api/am/publisher/v4/apis/copy-api?apiId=${source_id}&newVersion=2.0.0")

  local new_id=$(echo "$response" | jq -r ".id")

  if [ "$new_id" == "null" ] || [ -z "$new_id" ]; then
    echo "  SKIP: $(echo "$response" | jq -r ".description // .message // .")"
    return 0
  fi

  echo "  Creada: $new_id"

  # Publicar v2
  curl -sk -X POST \
    -H "Authorization: Bearer $TOKEN" \
    "https://localhost:9443/api/am/publisher/v4/apis/change-lifecycle?apiId=${new_id}&action=Publish" > /dev/null 2>&1

  echo "  Publicada"
}

echo ""
echo "=============================================="
echo "  APIs para subdominio: rrhh-empleados"
echo "=============================================="

create_api "EmployeeAPI" "1.0.0" "/employees" "rrhh-empleados"
EMPLOYEE_ID=$(cat /tmp/last_api_id.txt 2>/dev/null)
if [ -n "$EMPLOYEE_ID" ]; then
  create_api_v2 "$EMPLOYEE_ID" "EmployeeAPI"
fi

create_api "DepartmentAPI" "1.0.0" "/departments" "rrhh-empleados"
create_api "AttendanceAPI" "1.0.0" "/attendance" "rrhh-empleados"

echo ""
echo "=============================================="
echo "  APIs para subdominio: finanzas-pagos"
echo "=============================================="

create_api "PaymentAPI" "1.0.0" "/payments" "finanzas-pagos"
PAYMENT_ID=$(cat /tmp/last_api_id.txt 2>/dev/null)
if [ -n "$PAYMENT_ID" ]; then
  create_api_v2 "$PAYMENT_ID" "PaymentAPI"
fi

create_api "InvoiceAPI" "1.0.0" "/invoices" "finanzas-pagos"
create_api "AccountAPI" "1.0.0" "/accounts" "finanzas-pagos"

echo ""
echo "=============================================="
echo "  API sin subdominio (para probar validación)"
echo "=============================================="

create_api "TestAPI" "1.0.0" "/test" ""

echo ""
echo "=============================================="
echo "  Resumen de APIs creadas"
echo "=============================================="

printf "%-20s %-10s %-20s\n" "API" "VERSION" "SUBDOMINIO"
echo "----------------------------------------------"

curl -sk -H "Authorization: Bearer $TOKEN" \
  "https://localhost:9443/api/am/publisher/v4/apis?limit=20" | jq -r ".list[].id" | while read API_ID; do

  API_DATA=$(curl -sk -H "Authorization: Bearer $TOKEN" \
    "https://localhost:9443/api/am/publisher/v4/apis/${API_ID}")

  NAME=$(echo "$API_DATA" | jq -r ".name")
  VERSION=$(echo "$API_DATA" | jq -r ".version")
  SUBDOM=$(echo "$API_DATA" | jq -r ".additionalProperties[0].value // empty")

  [ -z "$SUBDOM" ] && SUBDOM="(sin subdominio)"

  printf "%-20s %-10s %-20s\n" "$NAME" "$VERSION" "$SUBDOM"
done | sort

echo ""
echo "=============================================="
echo "  APIs de prueba creadas correctamente!"
echo "=============================================="

# Limpiar
rm -f /tmp/last_api_id.txt
