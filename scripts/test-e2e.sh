#!/bin/bash
# =============================================================================
# APIOps E2E Test Suite
# =============================================================================
#
# Batería completa de pruebas para validar el sistema APIOps
#
# USO:
#   ./scripts/test-e2e.sh           # Ejecutar todas las pruebas
#   ./scripts/test-e2e.sh --quick   # Solo pruebas rápidas (sin workflows)
#   ./scripts/test-e2e.sh --verbose # Modo verbose
#
# PREREQUISITOS:
#   - WSO2 corriendo y healthy
#   - GitHub Runner corriendo
#   - APIs de ejemplo creadas
#   - Usuarios dev1 y dev2 creados
#
# =============================================================================

# No usar set -e para que las pruebas continúen aunque fallen

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración
WSO2_HOST="localhost"
WSO2_PORT="9443"
WSO2_ADMIN_USER="admin"
WSO2_ADMIN_PASS="admin"
GITHUB_OWNER="ISAngelRivera"
WSO2_PROCESSOR_REPO="WSO2-Processor"
HELIX_PROCESSOR_REPO="GIT-Helix-Processor"

# Contadores
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Flags
VERBOSE=false
QUICK_MODE=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --verbose|-v) VERBOSE=true ;;
        --quick|-q) QUICK_MODE=true ;;
        --help|-h)
            echo "USO: $0 [--quick] [--verbose]"
            exit 0
            ;;
    esac
done

# =============================================================================
# Funciones de utilidad
# =============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

log_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
    ((TESTS_SKIPPED++))
}

log_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${YELLOW}[DEBUG]${NC} $1"
    fi
}

section() {
    echo ""
    echo "=============================================="
    echo "  $1"
    echo "=============================================="
}

# Obtener token OAuth de WSO2
# Para usuarios no-admin, usa un cliente registrado por admin
get_token() {
    local username="${1:-admin}"
    local password="${2:-admin}"

    # Para admin, registrar cliente dinámicamente
    if [ "$username" == "admin" ]; then
        CLIENT_RESP=$(curl -sk -X POST \
            -H "Authorization: Basic $(echo -n "admin:admin" | base64)" \
            -H "Content-Type: application/json" \
            -d '{"callbackUrl":"https://localhost","clientName":"test_client_'$(date +%s)'","owner":"admin","grantType":"password","saasApp":true}' \
            "https://${WSO2_HOST}:${WSO2_PORT}/client-registration/v0.17/register")

        CID=$(echo "$CLIENT_RESP" | jq -r '.clientId')
        CS=$(echo "$CLIENT_RESP" | jq -r '.clientSecret')
    else
        # Para otros usuarios, usar cliente de admin
        CLIENT_RESP=$(curl -sk -X POST \
            -H "Authorization: Basic YWRtaW46YWRtaW4=" \
            -H "Content-Type: application/json" \
            -d '{"callbackUrl":"https://localhost","clientName":"shared_client_'$(date +%s)'","owner":"admin","grantType":"password","saasApp":true}' \
            "https://${WSO2_HOST}:${WSO2_PORT}/client-registration/v0.17/register")

        CID=$(echo "$CLIENT_RESP" | jq -r '.clientId')
        CS=$(echo "$CLIENT_RESP" | jq -r '.clientSecret')
    fi

    if [ -z "$CID" ] || [ "$CID" == "null" ]; then
        echo ""
        return
    fi

    TOKEN=$(curl -sk -X POST \
        -H "Authorization: Basic $(echo -n "${CID}:${CS}" | base64)" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=password&username=${username}&password=${password}&scope=apim:api_view apim:api_create apim:api_publish apim:api_delete" \
        "https://${WSO2_HOST}:${WSO2_PORT}/oauth2/token" | jq -r '.access_token')

    echo "$TOKEN"
}

# Listar APIs
list_apis() {
    local token="$1"
    curl -sk -H "Authorization: Bearer $token" \
        "https://${WSO2_HOST}:${WSO2_PORT}/api/am/publisher/v4/apis?limit=50"
}

# Obtener API por nombre
get_api_by_name() {
    local token="$1"
    local name="$2"
    local version="${3:-}"

    local query="name:${name}"
    [ -n "$version" ] && query="${query} version:${version}"

    curl -sk -H "Authorization: Bearer $token" \
        "https://${WSO2_HOST}:${WSO2_PORT}/api/am/publisher/v4/apis?query=${query}"
}

# Obtener detalles de API
get_api_details() {
    local token="$1"
    local api_id="$2"
    curl -sk -H "Authorization: Bearer $token" \
        "https://${WSO2_HOST}:${WSO2_PORT}/api/am/publisher/v4/apis/${api_id}"
}

# Crear API
create_api() {
    local token="$1"
    local name="$2"
    local version="$3"
    local context="$4"

    curl -sk -X POST \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"${name}\",
            \"version\": \"${version}\",
            \"context\": \"${context}\",
            \"endpointConfig\": {
                \"endpoint_type\": \"http\",
                \"production_endpoints\": {
                    \"url\": \"https://httpbin.org\"
                }
            }
        }" \
        "https://${WSO2_HOST}:${WSO2_PORT}/api/am/publisher/v4/apis"
}

# Añadir propiedad adicional a API
add_api_property() {
    local token="$1"
    local api_id="$2"
    local prop_name="$3"
    local prop_value="$4"

    # Obtener API actual
    local api_data=$(get_api_details "$token" "$api_id")

    # Añadir propiedad
    local updated=$(echo "$api_data" | jq ".additionalProperties = [{\"name\": \"${prop_name}\", \"value\": \"${prop_value}\", \"display\": true}]")

    curl -sk -X PUT \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d "$updated" \
        "https://${WSO2_HOST}:${WSO2_PORT}/api/am/publisher/v4/apis/${api_id}"
}

# Crear y desplegar revisión
deploy_revision() {
    local token="$1"
    local api_id="$2"

    # Crear revisión
    local rev_resp=$(curl -sk -X POST \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d '{"description": "Test revision"}' \
        "https://${WSO2_HOST}:${WSO2_PORT}/api/am/publisher/v4/apis/${api_id}/revisions")

    local rev_id=$(echo "$rev_resp" | jq -r '.id')
    log_verbose "Created revision: $rev_id"

    # Desplegar revisión
    curl -sk -X POST \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d '[{"name": "Default", "vhost": "localhost"}]' \
        "https://${WSO2_HOST}:${WSO2_PORT}/api/am/publisher/v4/apis/${api_id}/deploy-revision?revisionId=${rev_id}"

    echo "$rev_id"
}

# Verificar revisiones desplegadas
get_deployed_revisions() {
    local token="$1"
    local api_id="$2"

    curl -sk -H "Authorization: Bearer $token" \
        "https://${WSO2_HOST}:${WSO2_PORT}/api/am/publisher/v4/apis/${api_id}/revisions?query=deployed:true"
}

# Disparar workflow de UAT
trigger_uat_workflow() {
    local api_id="$1"
    local api_name="$2"
    local api_version="$3"
    local user_id="${4:-admin}"

    local request_id="REQ-test-$(date +%s)-$(echo $RANDOM | cut -c1-4)"

    gh workflow run receive-uat-request.yml \
        --repo "${GITHUB_OWNER}/${WSO2_PROCESSOR_REPO}" \
        -f requestId="$request_id" \
        -f apiId="$api_id" \
        -f apiName="$api_name" \
        -f apiVersion="$api_version" \
        -f userId="$user_id" 2>&1

    echo "$request_id"
}

# Esperar resultado de workflow
wait_for_workflow() {
    local request_id="$1"
    local timeout="${2:-120}"
    local start_time=$(date +%s)

    log_verbose "Waiting for workflow with request_id: $request_id"

    while true; do
        local elapsed=$(($(date +%s) - start_time))
        if [ $elapsed -gt $timeout ]; then
            echo "TIMEOUT"
            return 1
        fi

        # Buscar el run
        local run=$(gh run list --repo "${GITHUB_OWNER}/${WSO2_PROCESSOR_REPO}" --limit 10 --json databaseId,displayTitle,status,conclusion 2>/dev/null | \
            jq -r ".[] | select(.displayTitle | contains(\"$request_id\"))")

        if [ -n "$run" ]; then
            local status=$(echo "$run" | jq -r '.status')
            local conclusion=$(echo "$run" | jq -r '.conclusion')

            if [ "$status" == "completed" ]; then
                echo "$conclusion"
                return 0
            fi
        fi

        sleep 5
    done
}

# Eliminar API
delete_api() {
    local token="$1"
    local api_id="$2"

    curl -sk -X DELETE \
        -H "Authorization: Bearer $token" \
        "https://${WSO2_HOST}:${WSO2_PORT}/api/am/publisher/v4/apis/${api_id}"
}

# =============================================================================
# PRUEBAS
# =============================================================================

section "1. INFRAESTRUCTURA"

# Test 1.1: WSO2 está corriendo
test_wso2_running() {
    if curl -sk https://${WSO2_HOST}:${WSO2_PORT}/carbon/admin/login.jsp > /dev/null 2>&1; then
        log_success "WSO2 está corriendo y accesible"
    else
        log_fail "WSO2 no está accesible"
        exit 1
    fi
}

# Test 1.2: GitHub Runner está corriendo
test_runner_running() {
    if docker ps | grep -q github-runner; then
        log_success "GitHub Runner está corriendo"
    else
        log_fail "GitHub Runner no está corriendo"
    fi
}

# Test 1.3: Publisher levanta correctamente
test_publisher_ui() {
    local resp=$(curl -sk -o /dev/null -w "%{http_code}" "https://${WSO2_HOST}:${WSO2_PORT}/publisher/")
    if [ "$resp" == "200" ] || [ "$resp" == "302" ]; then
        log_success "Publisher UI accesible (HTTP $resp)"
    else
        log_fail "Publisher UI no accesible (HTTP $resp)"
    fi
}

# Test 1.4: Podemos autenticarnos
test_authentication() {
    local token=$(get_token admin admin)
    if [ -n "$token" ] && [ "$token" != "null" ]; then
        log_success "Autenticación OAuth funciona"
    else
        log_fail "No se pudo obtener token OAuth"
        exit 1
    fi
}

test_wso2_running
test_runner_running
test_publisher_ui
test_authentication

section "2. APIs DE EJEMPLO"

# Test 2.1: Existen APIs de ejemplo
test_sample_apis_exist() {
    local token=$(get_token)
    local apis=$(list_apis "$token")
    local count=$(echo "$apis" | jq -r '.count // 0')

    if [ "$count" -ge 5 ]; then
        log_success "Existen $count APIs en el sistema"
        if [ "$VERBOSE" = true ]; then
            echo "$apis" | jq -r '.list[] | "  - \(.name) v\(.version)"'
        fi
    else
        log_fail "Solo hay $count APIs (esperadas >= 5)"
    fi
}

# Test 2.2: Verificar APIs con subdominio
test_apis_with_subdominio() {
    local token=$(get_token)
    local apis=$(list_apis "$token")
    local with_subdom=0

    for api_id in $(echo "$apis" | jq -r '.list[].id'); do
        local details=$(get_api_details "$token" "$api_id")
        local subdom=$(echo "$details" | jq -r '.additionalProperties[]? | select(.name=="subdominio") | .value // empty')
        if [ -n "$subdom" ]; then
            ((with_subdom++))
            log_verbose "API $(echo "$details" | jq -r '.name') tiene subdominio: $subdom"
        fi
    done

    if [ $with_subdom -ge 3 ]; then
        log_success "$with_subdom APIs tienen subdominio configurado"
    else
        log_fail "Solo $with_subdom APIs tienen subdominio (esperadas >= 3)"
    fi
}

test_sample_apis_exist
test_apis_with_subdominio

section "3. VALIDACIONES DE NEGOCIO"

# Variable global para ID de PizzaTestAPI
PIZZA_API_ID=""

# Test 3.1: Crear PizzaTestAPI sin subdominio
test_create_pizza_api() {
    if [ "$QUICK_MODE" = true ]; then
        log_skip "Creación de PizzaTestAPI (modo quick)"
        return
    fi

    local token=$(get_token)

    # Eliminar si existe
    local existing=$(get_api_by_name "$token" "PizzaTestAPI" "1.0.0")
    local existing_id=$(echo "$existing" | jq -r '.list[0].id // empty')
    if [ -n "$existing_id" ]; then
        log_verbose "Eliminando PizzaTestAPI existente..."
        delete_api "$token" "$existing_id" > /dev/null 2>&1
        sleep 2
    fi

    # Crear nueva
    local resp=$(create_api "$token" "PizzaTestAPI" "1.0.0" "/pizza-test")
    PIZZA_API_ID=$(echo "$resp" | jq -r '.id // empty')

    if [ -n "$PIZZA_API_ID" ] && [ "$PIZZA_API_ID" != "null" ]; then
        log_success "PizzaTestAPI creada (ID: ${PIZZA_API_ID:0:8}...)"

        # Desplegar inmediatamente para pruebas posteriores
        log_verbose "Desplegando revisión..."
        deploy_revision "$token" "$PIZZA_API_ID" > /dev/null 2>&1
        sleep 2
    else
        log_fail "No se pudo crear PizzaTestAPI"
        PIZZA_API_ID=""
    fi
}

# Test 3.2: Intentar UAT sin subdominio (debe fallar)
test_uat_without_subdominio() {
    if [ "$QUICK_MODE" = true ]; then
        log_skip "Prueba de UAT sin subdominio (modo quick)"
        return
    fi

    if [ -z "$PIZZA_API_ID" ] || [ "$PIZZA_API_ID" == "null" ]; then
        log_skip "PizzaTestAPI no disponible para prueba sin subdominio"
        return
    fi

    log_info "Disparando UAT sin subdominio (esperamos fallo)..."
    local request_id=$(trigger_uat_workflow "$PIZZA_API_ID" "PizzaTestAPI" "1.0.0")

    local result=$(wait_for_workflow "$request_id" 90)

    if [ "$result" == "failure" ]; then
        log_success "UAT sin subdominio falló correctamente"
    elif [ "$result" == "TIMEOUT" ]; then
        log_fail "Timeout esperando resultado"
    else
        log_fail "UAT sin subdominio debería haber fallado (resultado: $result)"
    fi
}

# Test 3.3: Añadir subdominio inválido y probar
# NOTA: Esta prueba verifica que el GIT-Helix-Processor rechace subdominios no configurados.
# El WSO2-Processor solo valida que exista el campo subdominio, no su validez.
# Por eso esperamos el segundo workflow (Helix-Processor) para validar.
test_uat_invalid_subdominio() {
    if [ "$QUICK_MODE" = true ]; then
        log_skip "Prueba de UAT con subdominio inválido (modo quick)"
        return
    fi

    if [ -z "$PIZZA_API_ID" ] || [ "$PIZZA_API_ID" == "null" ]; then
        log_skip "PizzaTestAPI no disponible para prueba de subdominio inválido"
        return
    fi

    local token=$(get_token)

    # Añadir subdominio inválido
    log_verbose "Configurando subdominio inválido..."
    add_api_property "$token" "$PIZZA_API_ID" "subdominio" "subdominio-inexistente" > /dev/null
    sleep 2

    log_info "Disparando UAT con subdominio inválido (validación en Helix-Processor)..."
    local request_id=$(trigger_uat_workflow "$PIZZA_API_ID" "PizzaTestAPI" "1.0.0")

    # Primero esperamos que WSO2-Processor termine (puede ser success porque pasa el subdominio)
    local wso2_result=$(wait_for_workflow "$request_id" 90)
    log_verbose "WSO2-Processor result: $wso2_result"

    # Luego verificamos el Helix-Processor (debe fallar por subdominio inválido)
    sleep 5  # Dar tiempo a que se dispare el segundo workflow

    # Buscar el run más reciente del Helix-Processor
    local helix_run=$(gh run list --repo "${GITHUB_OWNER}/${HELIX_PROCESSOR_REPO}" --limit 5 --json databaseId,status,conclusion,createdAt 2>/dev/null | \
        jq -r '.[] | select(.status=="completed") | "\(.conclusion)"' | head -1)

    if [ "$helix_run" == "failure" ]; then
        log_success "UAT con subdominio inválido: Helix-Processor rechazó correctamente"
    elif [ "$wso2_result" == "failure" ]; then
        log_success "UAT con subdominio inválido: WSO2-Processor rechazó"
    else
        log_fail "UAT con subdominio inválido debería haber fallado (WSO2: $wso2_result, Helix: $helix_run)"
    fi
}

# Test 3.4: API sin revisión desplegada
test_uat_without_deployment() {
    if [ "$QUICK_MODE" = true ]; then
        log_skip "Prueba de UAT sin deployment (modo quick)"
        return
    fi

    local token=$(get_token)

    # Crear nueva API sin deployment
    local existing=$(get_api_by_name "$token" "NoDeployTestAPI" "1.0.0")
    local existing_id=$(echo "$existing" | jq -r '.list[0].id // empty')
    if [ -n "$existing_id" ]; then
        delete_api "$token" "$existing_id" > /dev/null 2>&1
        sleep 2
    fi

    local resp=$(create_api "$token" "NoDeployTestAPI" "1.0.0" "/nodeploy-test")
    local api_id=$(echo "$resp" | jq -r '.id')

    # Añadir subdominio válido pero NO desplegar
    add_api_property "$token" "$api_id" "subdominio" "rrhh-empleados" > /dev/null
    sleep 2

    log_info "Disparando UAT sin deployment (esperamos fallo)..."
    local request_id=$(trigger_uat_workflow "$api_id" "NoDeployTestAPI" "1.0.0")

    local result=$(wait_for_workflow "$request_id" 90)

    # Limpiar
    delete_api "$token" "$api_id" > /dev/null 2>&1

    if [ "$result" == "failure" ]; then
        log_success "UAT sin deployment falló correctamente"
    elif [ "$result" == "TIMEOUT" ]; then
        log_fail "Timeout esperando resultado"
    else
        log_fail "UAT sin deployment debería haber fallado (resultado: $result)"
    fi
}

test_create_pizza_api
test_uat_without_subdominio
test_uat_invalid_subdominio
test_uat_without_deployment

section "4. FLUJO UAT COMPLETO"

# Test 4.1: UAT exitoso con configuración correcta
test_uat_success() {
    if [ "$QUICK_MODE" = true ]; then
        log_skip "Prueba de UAT exitoso (modo quick)"
        return
    fi

    local token=$(get_token)

    # Buscar una API con subdominio válido
    local apis=$(list_apis "$token")
    local test_api_id=""
    local test_api_name=""
    local test_api_version=""

    for api_id in $(echo "$apis" | jq -r '.list[].id'); do
        local details=$(get_api_details "$token" "$api_id")
        local subdom=$(echo "$details" | jq -r '.additionalProperties[]? | select(.name=="subdominio") | .value // empty')
        local deployed=$(get_deployed_revisions "$token" "$api_id" | jq -r '.count // 0')

        if [ -n "$subdom" ] && [ "$deployed" -gt 0 ]; then
            test_api_id="$api_id"
            test_api_name=$(echo "$details" | jq -r '.name')
            test_api_version=$(echo "$details" | jq -r '.version')
            log_verbose "Usando API: $test_api_name v$test_api_version (subdominio: $subdom)"
            break
        fi
    done

    if [ -z "$test_api_id" ]; then
        log_skip "No hay APIs con subdominio y deployment para probar"
        return
    fi

    log_info "Disparando UAT completo para $test_api_name..."
    local request_id=$(trigger_uat_workflow "$test_api_id" "$test_api_name" "$test_api_version")

    local result=$(wait_for_workflow "$request_id" 180)

    if [ "$result" == "success" ]; then
        log_success "UAT completo exitoso para $test_api_name"
    elif [ "$result" == "TIMEOUT" ]; then
        log_fail "Timeout esperando resultado de UAT completo"
    else
        log_fail "UAT completo falló (resultado: $result)"
    fi
}

test_uat_success

section "5. PRUEBAS DE USUARIO"

# Test 5.1: dev1 puede autenticarse (verifica que existe y tiene permisos)
test_dev1_auth() {
    local token=$(get_token dev1 "Dev1pass!" 2>/dev/null)
    if [ -n "$token" ] && [ "$token" != "null" ] && [ "$token" != "" ]; then
        log_success "dev1 puede autenticarse y obtener token"
    else
        log_skip "dev1 no configurado (crear con ./scripts/create-test-users.sh)"
    fi
}

# Test 5.2: dev2 puede autenticarse
test_dev2_auth() {
    local token=$(get_token dev2 "Dev2pass!" 2>/dev/null)
    if [ -n "$token" ] && [ "$token" != "null" ] && [ "$token" != "" ]; then
        log_success "dev2 puede autenticarse y obtener token"
    else
        log_skip "dev2 no configurado (crear con ./scripts/create-test-users.sh)"
    fi
}

# Test 5.3: dev1 puede listar APIs (tiene rol creator)
test_dev1_can_list_apis() {
    local token=$(get_token dev1 "Dev1pass!" 2>/dev/null)
    if [ -z "$token" ] || [ "$token" == "null" ]; then
        log_skip "dev1 API list (usuario no autenticado)"
        return
    fi

    local apis=$(curl -sk -H "Authorization: Bearer $token" \
        "https://${WSO2_HOST}:${WSO2_PORT}/api/am/publisher/v4/apis?limit=1" 2>/dev/null)
    local count=$(echo "$apis" | jq -r '.count // -1' 2>/dev/null)

    if [ "$count" -ge 0 ] 2>/dev/null; then
        log_success "dev1 puede listar APIs"
    else
        log_fail "dev1 no puede listar APIs (verificar rol Internal/creator)"
    fi
}

test_dev1_auth
test_dev2_auth
test_dev1_can_list_apis

section "6. PRUEBAS DE GIT"

# Test 6.1: Verificar repo RRHH-Empleados
test_rrhh_repo() {
    if gh repo view "${GITHUB_OWNER}/RRHH-Empleados" > /dev/null 2>&1; then
        log_success "Repo RRHH-Empleados existe"
    else
        log_fail "Repo RRHH-Empleados no existe"
    fi
}

# Test 6.2: Verificar repo Finanzas-Pagos
test_finanzas_repo() {
    if gh repo view "${GITHUB_OWNER}/Finanzas-Pagos" > /dev/null 2>&1; then
        log_success "Repo Finanzas-Pagos existe"
    else
        log_fail "Repo Finanzas-Pagos no existe"
    fi
}

# Test 6.3: Runner registrado en GitHub
test_runner_registered() {
    local runners=$(gh api repos/${GITHUB_OWNER}/${WSO2_PROCESSOR_REPO}/actions/runners 2>/dev/null)
    local count=$(echo "$runners" | jq -r '.total_count // 0')

    if [ "$count" -gt 0 ]; then
        local runner_name=$(echo "$runners" | jq -r '.runners[0].name')
        local runner_status=$(echo "$runners" | jq -r '.runners[0].status')
        log_success "Runner '$runner_name' registrado (status: $runner_status)"
    else
        log_fail "No hay runners registrados en GitHub"
    fi
}

test_rrhh_repo
test_finanzas_repo
test_runner_registered

section "7. LIMPIEZA"

# Limpiar APIs de prueba
cleanup_test_apis() {
    local token=$(get_token)

    for api_name in "PizzaTestAPI" "NoDeployTestAPI"; do
        local api=$(get_api_by_name "$token" "$api_name")
        local api_id=$(echo "$api" | jq -r '.list[0].id // empty')
        if [ -n "$api_id" ]; then
            delete_api "$token" "$api_id" > /dev/null 2>&1
            log_verbose "Eliminada API de prueba: $api_name"
        fi
    done

    log_success "APIs de prueba eliminadas"
}

cleanup_test_apis

# =============================================================================
# RESUMEN
# =============================================================================

section "RESUMEN DE PRUEBAS"

TOTAL=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))

echo ""
echo -e "  ${GREEN}Pasadas:${NC}  $TESTS_PASSED"
echo -e "  ${RED}Fallidas:${NC} $TESTS_FAILED"
echo -e "  ${YELLOW}Saltadas:${NC} $TESTS_SKIPPED"
echo -e "  Total:    $TOTAL"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}=============================================="
    echo -e "  TODAS LAS PRUEBAS PASARON"
    echo -e "==============================================${NC}"
    exit 0
else
    echo -e "${RED}=============================================="
    echo -e "  HAY PRUEBAS FALLIDAS"
    echo -e "==============================================${NC}"
    exit 1
fi
