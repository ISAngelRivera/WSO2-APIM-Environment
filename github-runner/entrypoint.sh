#!/bin/bash
set -e

# ============================================
# GitHub Actions Runner Entrypoint
# ============================================
# Este script:
# 1. Obtiene un token de registro de GitHub
# 2. Configura el runner
# 3. Ejecuta el runner
# 4. Limpia al salir (de-registra el runner)

echo "========================================"
echo "  GitHub Actions Runner - APIOps"
echo "========================================"

# Validar variables requeridas
if [ -z "$GITHUB_TOKEN" ]; then
    echo "ERROR: GITHUB_TOKEN no está configurado"
    echo "Necesitas un Personal Access Token con scope 'repo'"
    exit 1
fi

if [ -z "$GITHUB_OWNER" ]; then
    echo "ERROR: GITHUB_OWNER no está configurado"
    exit 1
fi

if [ -z "$GITHUB_REPO" ]; then
    echo "ERROR: GITHUB_REPO no está configurado"
    exit 1
fi

# Nombre del runner (único)
RUNNER_NAME="${RUNNER_NAME:-apiops-runner-$(hostname)}"
echo "Runner name: $RUNNER_NAME"
echo "Repository: $GITHUB_OWNER/$GITHUB_REPO"
echo "Labels: $RUNNER_LABELS"

# Función para limpiar al salir
cleanup() {
    echo ""
    echo "Limpiando runner..."

    # Obtener token de eliminación
    REMOVE_TOKEN=$(curl -s -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/actions/runners/remove-token" \
        | jq -r '.token')

    if [ "$REMOVE_TOKEN" != "null" ] && [ -n "$REMOVE_TOKEN" ]; then
        ./config.sh remove --token "$REMOVE_TOKEN" || true
        echo "Runner de-registrado correctamente"
    else
        echo "No se pudo obtener token de eliminación (el runner puede quedar huérfano)"
    fi
}

# Registrar la función de limpieza
trap cleanup EXIT SIGTERM SIGINT

# Obtener token de registro
echo ""
echo "Obteniendo token de registro..."
REG_TOKEN=$(curl -s -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/actions/runners/registration-token" \
    | jq -r '.token')

if [ "$REG_TOKEN" == "null" ] || [ -z "$REG_TOKEN" ]; then
    echo "ERROR: No se pudo obtener token de registro"
    echo "Verifica que GITHUB_TOKEN tenga scope 'repo'"
    exit 1
fi

echo "Token de registro obtenido"

# Configurar el runner
echo ""
echo "Configurando runner..."
./config.sh \
    --url "https://github.com/$GITHUB_OWNER/$GITHUB_REPO" \
    --token "$REG_TOKEN" \
    --name "$RUNNER_NAME" \
    --labels "$RUNNER_LABELS" \
    --work "$RUNNER_WORKDIR" \
    --unattended \
    --replace

echo ""
echo "========================================"
echo "  Runner configurado y listo!"
echo "  Esperando jobs..."
echo "========================================"

# Ejecutar el runner
./run.sh
