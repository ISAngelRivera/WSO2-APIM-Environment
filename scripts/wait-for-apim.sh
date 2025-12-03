#!/bin/bash
#
# wait-for-apim.sh
# Espera a que WSO2 APIM esté completamente iniciado
#
# Uso: ./scripts/wait-for-apim.sh [timeout_seconds]

set -e

TIMEOUT=${1:-300}  # 5 minutos por defecto
INTERVAL=10
ELAPSED=0

APIM_URL="https://localhost:9443/carbon/admin/login.jsp"

echo "════════════════════════════════════════════════════════════"
echo "  Esperando a que WSO2 API Manager esté listo..."
echo "  URL: $APIM_URL"
echo "  Timeout: ${TIMEOUT}s"
echo "════════════════════════════════════════════════════════════"

while [ $ELAPSED -lt $TIMEOUT ]; do
    if curl -k -s -f "$APIM_URL" > /dev/null 2>&1; then
        echo ""
        echo "✓ WSO2 API Manager está listo! (${ELAPSED}s)"
        echo ""
        exit 0
    fi

    echo "  Esperando... (${ELAPSED}s / ${TIMEOUT}s)"
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
done

echo ""
echo "✗ Timeout: WSO2 API Manager no respondió en ${TIMEOUT}s"
echo "  Revisa los logs: docker-compose logs -f wso2-apim"
echo ""
exit 1
