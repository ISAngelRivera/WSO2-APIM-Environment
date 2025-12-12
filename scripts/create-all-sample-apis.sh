#!/bin/bash
#
# create-all-sample-apis.sh
# Crea el set completo de 10 APIs de prueba para validar el flujo APIOps
#
# Casos de uso cubiertos:
#   - APIs simples (1 versión, 1 revisión)
#   - APIs con múltiples versiones (v1.0.0, v2.0.0)
#   - APIs con múltiples revisiones
#   - API deprecada
#   - Diferentes dominios/subdominios
#
# Distribución:
#   - Informatica-DevOps: 4 APIs
#   - apim-domain-finanzas: 6 APIs
#
# Uso: ./scripts/create-all-sample-apis.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/api-helpers.sh"

echo "════════════════════════════════════════════════════════════"
echo "  Creando Set Completo de APIs de Prueba"
echo "════════════════════════════════════════════════════════════"
echo ""

# Obtener token
echo "[0/10] Obteniendo token de acceso..."
get_access_token

# ══════════════════════════════════════════════════════════════
# DOMINIO: Informatica-DevOps (4 APIs)
# ══════════════════════════════════════════════════════════════

echo ""
echo "═══ DOMINIO: Informatica-DevOps ═══"
echo ""

# --- PizzaAPI: Múltiples versiones y revisiones ---
echo "[1/10] PizzaAPI - Múltiples versiones y revisiones..."
create_api "PizzaAPI" "1.0.0" "/pizza" "Informatica" "DevOps" \
    "API para gestión de pedidos de pizza" \
    '[{"target":"/menu","verb":"GET"},{"target":"/order","verb":"POST"},{"target":"/order/{id}","verb":"GET"}]'

create_revision "PizzaAPI" "1.0.0" "Añadido endpoint /menu/specials"
create_revision "PizzaAPI" "1.0.0" "Fix en validación de pedidos"

echo "        Creando versión 2.0.0..."
create_api_version "PizzaAPI" "1.0.0" "2.0.0"
create_revision "PizzaAPI" "2.0.0" "Nuevo endpoint /schedule para pedidos programados"

# --- OrderAPI: Una versión con múltiples revisiones ---
echo "[2/10] OrderAPI - Una versión con múltiples revisiones..."
create_api "OrderAPI" "1.0.0" "/orders" "Informatica" "DevOps" \
    "API de gestión de órdenes internas" \
    '[{"target":"/","verb":"GET"},{"target":"/","verb":"POST"},{"target":"/{id}","verb":"GET"},{"target":"/{id}/status","verb":"PUT"}]'

create_revision "OrderAPI" "1.0.0" "Añadido filtro por fecha"
create_revision "OrderAPI" "1.0.0" "Soporte para paginación"

# --- InventoryAPI: Caso simple ---
echo "[3/10] InventoryAPI - Caso simple..."
create_api "InventoryAPI" "1.0.0" "/inventory" "Informatica" "DevOps" \
    "API de control de inventario" \
    '[{"target":"/products","verb":"GET"},{"target":"/products/{sku}","verb":"GET"},{"target":"/stock","verb":"PUT"}]'

# --- NotificationAPI: Dos versiones minor ---
echo "[4/10] NotificationAPI - Versiones minor (1.0.0 y 1.1.0)..."
create_api "NotificationAPI" "1.0.0" "/notifications" "Informatica" "DevOps" \
    "API de notificaciones push y email" \
    '[{"target":"/send","verb":"POST"},{"target":"/templates","verb":"GET"}]'

create_api_version "NotificationAPI" "1.0.0" "1.1.0"
create_revision "NotificationAPI" "1.1.0" "Añadido soporte SMS"


# ══════════════════════════════════════════════════════════════
# DOMINIO: apim-domain-finanzas (6 APIs)
# ══════════════════════════════════════════════════════════════

echo ""
echo "═══ DOMINIO: apim-domain-finanzas ═══"
echo ""

# --- PaymentAPI: Ciclo de vida completo con deprecated ---
echo "[5/10] PaymentAPI - Lifecycle completo (v1 deprecated, v2, v3)..."
create_api "PaymentAPI" "1.0.0" "/payments" "Finanzas" "Pagos" \
    "API de pagos legacy - SERÁ DEPRECADA" \
    '[{"target":"/process","verb":"POST"}]'

deprecate_api "PaymentAPI" "1.0.0"

create_api "PaymentAPI2" "1.0.0" "/payments-v2" "Finanzas" "Pagos" \
    "API de pagos con soporte 3DS" \
    '[{"target":"/process","verb":"POST"},{"target":"/verify","verb":"POST"},{"target":"/{id}","verb":"GET"}]'

create_revision "PaymentAPI2" "1.0.0" "Mejora en manejo de errores 3DS"

create_api_version "PaymentAPI2" "1.0.0" "2.0.0"
create_revision "PaymentAPI2" "2.0.0" "Soporte para tokenización"

# --- InvoiceAPI: Muchas revisiones ---
echo "[6/10] InvoiceAPI - Muchas revisiones..."
create_api "InvoiceAPI" "1.0.0" "/invoices" "Finanzas" "Pagos" \
    "API de facturación electrónica" \
    '[{"target":"/","verb":"POST"},{"target":"/{id}","verb":"GET"},{"target":"/{id}/pdf","verb":"GET"}]'

create_revision "InvoiceAPI" "1.0.0" "Soporte para facturas rectificativas"
create_revision "InvoiceAPI" "1.0.0" "Integración con SII"
create_revision "InvoiceAPI" "1.0.0" "Validación de NIF mejorada"

# --- RefundAPI: Simple ---
echo "[7/10] RefundAPI - Caso simple..."
create_api "RefundAPI" "1.0.0" "/refunds" "Finanzas" "Pagos" \
    "API de gestión de devoluciones" \
    '[{"target":"/","verb":"POST"},{"target":"/{id}","verb":"GET"},{"target":"/{id}/status","verb":"GET"}]'

# --- WalletAPI: Dos versiones activas ---
echo "[8/10] WalletAPI - Dos versiones activas..."
create_api "WalletAPI" "1.0.0" "/wallet" "Finanzas" "Pagos" \
    "API de monedero digital" \
    '[{"target":"/balance","verb":"GET"},{"target":"/topup","verb":"POST"},{"target":"/withdraw","verb":"POST"}]'

create_api_version "WalletAPI" "1.0.0" "2.0.0"
create_revision "WalletAPI" "2.0.0" "Soporte multi-divisa"

# --- TransferAPI: Simple ---
echo "[9/10] TransferAPI - Caso simple..."
create_api "TransferAPI" "1.0.0" "/transfers" "Finanzas" "Pagos" \
    "API de transferencias bancarias" \
    '[{"target":"/","verb":"POST"},{"target":"/{id}","verb":"GET"},{"target":"/validate-iban","verb":"POST"}]'

# --- FraudDetectionAPI: Con revisiones ---
echo "[10/10] FraudDetectionAPI - Con revisiones..."
create_api "FraudDetectionAPI" "1.0.0" "/fraud" "Finanzas" "Pagos" \
    "API de detección de fraude en tiempo real" \
    '[{"target":"/analyze","verb":"POST"},{"target":"/rules","verb":"GET"},{"target":"/report/{txId}","verb":"GET"}]'

create_revision "FraudDetectionAPI" "1.0.0" "Nuevas reglas ML para detección"
create_revision "FraudDetectionAPI" "1.0.0" "Integración con servicio externo antifraude"


# ══════════════════════════════════════════════════════════════
# RESUMEN
# ══════════════════════════════════════════════════════════════

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  ✓ APIs Creadas Exitosamente"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "  INFORMATICA-DEVOPS (4 APIs base, 6 versiones total):"
echo "    • PizzaAPI        v1.0.0 (3 rev), v2.0.0 (2 rev)"
echo "    • OrderAPI        v1.0.0 (3 rev)"
echo "    • InventoryAPI    v1.0.0 (1 rev)"
echo "    • NotificationAPI v1.0.0 (1 rev), v1.1.0 (2 rev)"
echo ""
echo "  FINANZAS-PAGOS (6 APIs base, 10 versiones total):"
echo "    • PaymentAPI      v1.0.0 [DEPRECATED]"
echo "    • PaymentAPI2     v1.0.0 (2 rev), v2.0.0 (2 rev)"
echo "    • InvoiceAPI      v1.0.0 (4 rev)"
echo "    • RefundAPI       v1.0.0 (1 rev)"
echo "    • WalletAPI       v1.0.0 (1 rev), v2.0.0 (2 rev)"
echo "    • TransferAPI     v1.0.0 (1 rev)"
echo "    • FraudDetectionAPI v1.0.0 (3 rev)"
echo ""
echo "  Casos de uso cubiertos:"
echo "    ✓ API simple (1 versión, 1 revisión)"
echo "    ✓ Múltiples versiones del mismo API"
echo "    ✓ Múltiples revisiones de una versión"
echo "    ✓ API deprecada"
echo "    ✓ Versiones minor (1.0 → 1.1)"
echo "    ✓ Dos dominios diferentes"
echo ""
echo "  Próximo paso: Abre https://localhost:9443/publisher"
echo "                y prueba el botón 'Register UAT'"
echo ""
