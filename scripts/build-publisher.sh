#!/bin/bash
# =============================================================================
# Script para compilar el Publisher de WSO2 con el componente UATRegistration
# =============================================================================
#
# Este script:
# 1. Clona el repositorio apim-apps de WSO2 (si no existe)
# 2. Aplica el patch con UATRegistration
# 3. Compila el Publisher con pnpm (seguro)
# 4. Copia los bundles al dropin
#
# Uso: ./scripts/build-publisher.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
WSO2_SOURCE="$PROJECT_DIR/wso2-source"
WEBAPP_DIR="$WSO2_SOURCE/apim-apps/portals/publisher/src/main/webapp"
DROPIN_DIR="$PROJECT_DIR/publisher-dropin"
DROPIN_PAGES_DIR="$PROJECT_DIR/publisher-dropin-pages"
PATCH_FILE="$PROJECT_DIR/wso2-patch/uat-registration-feature.patch"

echo "=============================================="
echo "  Build del Publisher con UATRegistration"
echo "=============================================="

# 1. Clonar repositorio si no existe
if [ ! -d "$WSO2_SOURCE/apim-apps" ]; then
    echo ""
    echo ">>> Clonando repositorio apim-apps..."
    mkdir -p "$WSO2_SOURCE"
    cd "$WSO2_SOURCE"
    git clone --depth 1 --branch v9.3.119 https://github.com/wso2/apim-apps.git
else
    echo ""
    echo ">>> Repositorio ya existe, usando existente..."
fi

cd "$WEBAPP_DIR"

# 2. Aplicar patch si existe y no está aplicado
if [ -f "$PATCH_FILE" ]; then
    if [ ! -f "source/src/app/components/Apis/Details/LifeCycle/Components/UATRegistration.jsx" ]; then
        echo ""
        echo ">>> Aplicando patch de UATRegistration..."
        git apply "$PATCH_FILE" || echo "Patch ya aplicado o no aplica"
    else
        echo ""
        echo ">>> UATRegistration.jsx ya existe, saltando patch..."
    fi
fi

# 3. Instalar dependencias
echo ""
echo ">>> Instalando dependencias con pnpm..."
pnpm install --frozen-lockfile --ignore-scripts

# 4. Compilar
echo ""
echo ">>> Compilando para producción..."
pnpm run build:prod

# 5. Copiar al dropin
echo ""
echo ">>> Copiando bundles al dropin..."
mkdir -p "$DROPIN_DIR"
mkdir -p "$DROPIN_PAGES_DIR"
rm -rf "$DROPIN_DIR"/*
cp -r site/public/dist/* "$DROPIN_DIR/"
cp site/public/pages/index.jsp "$DROPIN_PAGES_DIR/"

echo ""
echo "=============================================="
echo "  Build completado exitosamente!"
echo "=============================================="
echo ""
echo "Dropin en: $DROPIN_DIR"
echo "index.jsp en: $DROPIN_PAGES_DIR"
echo ""
echo "Para usar, ejecuta: docker compose up -d"
