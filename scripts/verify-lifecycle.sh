#!/bin/bash
#
# verify-lifecycle.sh
# Verifica que el lifecycle estándar esté configurado en el tenant-config
#
# Uso: ./scripts/verify-lifecycle.sh

set -e

echo "Verificando lifecycle estándar..."

# Registrar cliente OAuth
CLIENT_RESPONSE=$(curl -s -k -X POST \
  "https://localhost:9443/client-registration/v0.17/register" \
  -H "Authorization: Basic YWRtaW46YWRtaW4=" \
  -H "Content-Type: application/json" \
  -d '{"callbackUrl":"https://localhost","clientName":"verify_lc","owner":"admin","grantType":"password","saasApp":true}')

CLIENT_ID=$(echo "$CLIENT_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['clientId'])" 2>/dev/null)
CLIENT_SECRET=$(echo "$CLIENT_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['clientSecret'])" 2>/dev/null)

if [ -z "$CLIENT_ID" ]; then
    echo "  ✗ ERROR: No se pudo registrar cliente OAuth"
    exit 1
fi

# Obtener token
TOKEN=$(curl -s -k -X POST \
  "https://localhost:9443/oauth2/token" \
  -u "$CLIENT_ID:$CLIENT_SECRET" \
  -d "grant_type=password&username=admin&password=admin&scope=apim:admin apim:tenantInfo" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null)

if [ -z "$TOKEN" ]; then
    echo "  ✗ ERROR: No se pudo obtener token"
    exit 1
fi

# Verificar que el lifecycle tiene los estados estándar
RESULT=$(curl -s -k -X GET \
  "https://localhost:9443/api/am/admin/v4/tenant-config" \
  -H "Authorization: Bearer $TOKEN" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if 'LifeCycle' not in data:
    print('no_lifecycle')
else:
    states = [s['State'] for s in data['LifeCycle'].get('States', [])]
    required_states = {'Created', 'Published', 'Blocked', 'Deprecated', 'Retired'}

    if required_states.issubset(set(states)):
        # Verificar que NO existe Register UAT (estado obsoleto)
        if 'Registered UAT' in states:
            print('has_old_state')
        else:
            # Verificar transiciones desde Published
            for state in data['LifeCycle']['States']:
                if state['State'] == 'Published':
                    transitions = [t['Event'] for t in state.get('Transitions', [])]
                    if 'Publish' in transitions and 'Deprecate' in transitions:
                        print('ok')
                    else:
                        print('missing_transitions')
                    break
    else:
        missing = required_states - set(states)
        print(f'missing_states:{list(missing)}')
" 2>/dev/null)

case "$RESULT" in
    "ok")
        echo "  ✓ Lifecycle estándar configurado correctamente"
        echo ""
        echo "  Estados disponibles:"
        echo "    Created → Published → Blocked → Deprecated → Retired"
        echo ""
        echo "  NOTA: El registro en UAT se realiza desde el componente React"
        echo "        en la página de Lifecycle del Publisher."
        ;;
    "no_lifecycle")
        echo "  ✗ ERROR: LifeCycle no configurado en tenant-config"
        echo "    Ejecuta: ./scripts/configure-lifecycle.sh"
        exit 1
        ;;
    "has_old_state")
        echo "  ✗ ERROR: Se encontró estado obsoleto 'Registered UAT'"
        echo "    Ejecuta: ./scripts/configure-lifecycle.sh"
        exit 1
        ;;
    missing_states:*)
        echo "  ✗ ERROR: Estados faltantes: ${RESULT#missing_states:}"
        echo "    Ejecuta: ./scripts/configure-lifecycle.sh"
        exit 1
        ;;
    "missing_transitions")
        echo "  ✗ ERROR: Transiciones faltantes en estado Published"
        echo "    Ejecuta: ./scripts/configure-lifecycle.sh"
        exit 1
        ;;
    *)
        echo "  ✗ ERROR: Resultado inesperado: $RESULT"
        exit 1
        ;;
esac
