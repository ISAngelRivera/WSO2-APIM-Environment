#!/bin/bash
#
# create-all-sample-apis.sh
# Crea el set completo de 10 APIs de prueba para validar el flujo APIOps
#
# Distribución:
#   - Informatica-DevOps: 4 APIs (PizzaAPI, OrderAPI, InventoryAPI, NotificationAPI)
#   - Finanzas-Pagos: 6 APIs (PaymentAPI, InvoiceAPI, RefundAPI, WalletAPI, TransferAPI, FraudDetectionAPI)
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
echo "[1/10] PizzaAPI v1.0.0 (3 revisiones)..."
create_api "PizzaAPI" "1.0.0" "/pizza" "Informatica" "DevOps" \
    "API para gestión de pedidos de pizza" \
    '[{"target":"/menu","verb":"GET"},{"target":"/order","verb":"POST"},{"target":"/order/{id}","verb":"GET"}]'

# Simular revisiones actualizando el API
echo "        Creando revisión 2..."
create_revision "PizzaAPI" "1.0.0" "Añadido endpoint /menu/specials"

echo "        Creando revisión 3..."
create_revision "PizzaAPI" "1.0.0" "Fix en validación de pedidos"

echo "        Creando PizzaAPI v2.0.0..."
create_api "PizzaAPI" "2.0.0" "/pizza/v2" "Informatica" "DevOps" \
    "API v2 con soporte para pedidos programados" \
    '[{"target":"/menu","verb":"GET"},{"target":"/order","verb":"POST"},{"target":"/order/{id}","verb":"GET"},{"target":"/schedule","verb":"POST"}]'

# --- OrderAPI: Revisiones en una versión ---
echo "[2/10] OrderAPI v1.0.0 (2 revisiones)..."
create_api "OrderAPI" "1.0.0" "/orders" "Informatica" "DevOps" \
    "API de gestión de órdenes internas" \
    '[{"target":"/","verb":"GET"},{"target":"/","verb":"POST"},{"target":"/{id}","verb":"GET"},{"target":"/{id}/status","verb":"PUT"}]'

echo "        Creando revisión 2..."
create_revision "OrderAPI" "1.0.0" "Añadido filtro por fecha"

# --- InventoryAPI: Caso simple ---
echo "[3/10] InventoryAPI v1.0.0 (simple)..."
create_api "InventoryAPI" "1.0.0" "/inventory" "Informatica" "DevOps" \
    "API de control de inventario" \
    '[{"target":"/products","verb":"GET"},{"target":"/products/{sku}","verb":"GET"},{"target":"/stock","verb":"PUT"}]'

# --- NotificationAPI: Versiones minor ---
echo "[4/10] NotificationAPI v1.0.0 y v1.1.0..."
create_api "NotificationAPI" "1.0.0" "/notifications" "Informatica" "DevOps" \
    "API de notificaciones push y email" \
    '[{"target":"/send","verb":"POST"},{"target":"/templates","verb":"GET"}]'

create_api "NotificationAPI" "1.1.0" "/notifications/v1.1" "Informatica" "DevOps" \
    "API de notificaciones con soporte SMS" \
    '[{"target":"/send","verb":"POST"},{"target":"/templates","verb":"GET"},{"target":"/sms","verb":"POST"}]'


# ══════════════════════════════════════════════════════════════
# DOMINIO: Finanzas-Pagos (6 APIs)
# ══════════════════════════════════════════════════════════════

echo ""
echo "═══ DOMINIO: Finanzas-Pagos ═══"
echo ""

# --- PaymentAPI: Lifecycle completo con deprecated ---
echo "[5/10] PaymentAPI v1.0.0 (deprecated), v2.0.0, v3.0.0..."
create_api "PaymentAPI" "1.0.0" "/payments/v1" "Finanzas" "Pagos" \
    "API de pagos legacy - DEPRECATED" \
    '[{"target":"/process","verb":"POST"}]'
deprecate_api "PaymentAPI" "1.0.0"

create_api "PaymentAPI" "2.0.0" "/payments/v2" "Finanzas" "Pagos" \
    "API de pagos con soporte 3DS" \
    '[{"target":"/process","verb":"POST"},{"target":"/verify","verb":"POST"},{"target":"/{id}","verb":"GET"}]'

echo "        Creando revisión 2 de v2.0.0..."
create_revision "PaymentAPI" "2.0.0" "Mejora en manejo de errores 3DS"

create_api "PaymentAPI" "3.0.0" "/payments/v3" "Finanzas" "Pagos" \
    "API de pagos con tokenización" \
    '[{"target":"/process","verb":"POST"},{"target":"/tokenize","verb":"POST"},{"target":"/{id}","verb":"GET"},{"target":"/refund","verb":"POST"}]'

# --- InvoiceAPI: Muchas revisiones ---
echo "[6/10] InvoiceAPI v1.0.0 (3 revisiones)..."
create_api "InvoiceAPI" "1.0.0" "/invoices" "Finanzas" "Pagos" \
    "API de facturación electrónica" \
    '[{"target":"/","verb":"POST"},{"target":"/{id}","verb":"GET"},{"target":"/{id}/pdf","verb":"GET"}]'

echo "        Creando revisión 2..."
create_revision "InvoiceAPI" "1.0.0" "Soporte para facturas rectificativas"

echo "        Creando revisión 3..."
create_revision "InvoiceAPI" "1.0.0" "Integración con SII"

# --- RefundAPI: Simple ---
echo "[7/10] RefundAPI v1.0.0 (simple)..."
create_api "RefundAPI" "1.0.0" "/refunds" "Finanzas" "Pagos" \
    "API de gestión de devoluciones" \
    '[{"target":"/","verb":"POST"},{"target":"/{id}","verb":"GET"},{"target":"/{id}/status","verb":"GET"}]'

# --- WalletAPI: Dos versiones activas ---
echo "[8/10] WalletAPI v1.0.0 y v2.0.0..."
create_api "WalletAPI" "1.0.0" "/wallet" "Finanzas" "Pagos" \
    "API de monedero digital" \
    '[{"target":"/balance","verb":"GET"},{"target":"/topup","verb":"POST"},{"target":"/withdraw","verb":"POST"}]'

create_api "WalletAPI" "2.0.0" "/wallet/v2" "Finanzas" "Pagos" \
    "API de monedero con multi-divisa" \
    '[{"target":"/balance","verb":"GET"},{"target":"/balance/{currency}","verb":"GET"},{"target":"/topup","verb":"POST"},{"target":"/exchange","verb":"POST"}]'

# --- TransferAPI: Simple ---
echo "[9/10] TransferAPI v1.0.0 (simple)..."
create_api "TransferAPI" "1.0.0" "/transfers" "Finanzas" "Pagos" \
    "API de transferencias bancarias" \
    '[{"target":"/","verb":"POST"},{"target":"/{id}","verb":"GET"},{"target":"/validate-iban","verb":"POST"}]'

# --- FraudDetectionAPI: Con revisiones ---
echo "[10/10] FraudDetectionAPI v1.0.0 (2 revisiones)..."
create_api "FraudDetectionAPI" "1.0.0" "/fraud" "Finanzas" "Pagos" \
    "API de detección de fraude en tiempo real" \
    '[{"target":"/analyze","verb":"POST"},{"target":"/rules","verb":"GET"},{"target":"/report/{txId}","verb":"GET"}]'

echo "         Creando revisión 2..."
create_revision "FraudDetectionAPI" "1.0.0" "Nuevas reglas ML para detección"


# ══════════════════════════════════════════════════════════════
# RESUMEN
# ══════════════════════════════════════════════════════════════

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  ✓ APIs Creadas Exitosamente"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "  INFORMATICA-DEVOPS (4 APIs):"
echo "    • PizzaAPI        v1.0.0 (3 rev), v2.0.0 (1 rev)"
echo "    • OrderAPI        v1.0.0 (2 rev)"
echo "    • InventoryAPI    v1.0.0 (1 rev)"
echo "    • NotificationAPI v1.0.0 (1 rev), v1.1.0 (1 rev)"
echo ""
echo "  FINANZAS-PAGOS (6 APIs):"
echo "    • PaymentAPI        v1.0.0 (DEPRECATED), v2.0.0 (2 rev), v3.0.0 (1 rev)"
echo "    • InvoiceAPI        v1.0.0 (3 rev)"
echo "    • RefundAPI         v1.0.0 (1 rev)"
echo "    • WalletAPI         v1.0.0 (1 rev), v2.0.0 (1 rev)"
echo "    • TransferAPI       v1.0.0 (1 rev)"
echo "    • FraudDetectionAPI v1.0.0 (2 rev)"
echo ""
echo "  Total: 10 APIs, 16 versiones, 20 revisiones"
echo ""
echo "  Próximo paso: Abre https://localhost:9443/publisher"
echo "                y prueba el botón 'Register UAT'"
echo ""
