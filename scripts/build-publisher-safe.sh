#!/bin/bash
#
# Build WSO2 Publisher con pnpm de forma segura
#
# Medidas de seguridad:
# 1. Usa pnpm (más seguro que npm)
# 2. Frozen lockfile (no modifica dependencias)
# 3. No ejecuta scripts de lifecycle por defecto
# 4. Auditoría de vulnerabilidades antes de instalar
#
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PUBLISHER_DIR="$PROJECT_ROOT/wso2-source/apim-apps/portals/publisher/src/main/webapp"

echo "════════════════════════════════════════════════════════════"
echo "  WSO2 Publisher - Build Seguro con pnpm"
echo "════════════════════════════════════════════════════════════"
echo ""

# Verificar que pnpm está instalado
if ! command -v pnpm &> /dev/null; then
    echo "⚠️  pnpm no está instalado."
    echo ""
    echo "Para instalar pnpm de forma segura:"
    echo "  curl -fsSL https://get.pnpm.io/install.sh | sh -"
    echo ""
    echo "O con npm (verificando primero):"
    echo "  npm install -g pnpm"
    echo ""
    exit 1
fi

echo "✓ pnpm encontrado: $(pnpm --version)"
echo ""

cd "$PUBLISHER_DIR"

echo "📁 Directorio: $PUBLISHER_DIR"
echo ""

# Paso 1: Verificar integridad del lockfile
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Paso 1: Verificando lockfile..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -f "package-lock.json" ]; then
    echo "✓ package-lock.json encontrado ($(wc -l < package-lock.json) líneas)"
else
    echo "✗ No hay package-lock.json - abortando"
    exit 1
fi
echo ""

# Paso 2: Convertir lockfile de npm a pnpm (si es necesario)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Paso 2: Importando lockfile a formato pnpm..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ ! -f "pnpm-lock.yaml" ]; then
    pnpm import
    echo "✓ Lockfile convertido a pnpm-lock.yaml"
else
    echo "✓ pnpm-lock.yaml ya existe"
fi
echo ""

# Paso 3: Auditoría de seguridad
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Paso 3: Ejecutando auditoría de seguridad..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Ejecutando: pnpm audit"
echo ""

AUDIT_RESULT=$(pnpm audit 2>&1 || true)
echo "$AUDIT_RESULT"

# Contar vulnerabilidades críticas y altas
CRITICAL=$(echo "$AUDIT_RESULT" | grep -c "critical" || echo "0")
HIGH=$(echo "$AUDIT_RESULT" | grep -c "high" || echo "0")

echo ""
if [ "$CRITICAL" != "0" ]; then
    echo "⚠️  Se encontraron $CRITICAL vulnerabilidades CRÍTICAS"
    echo ""
    read -p "¿Deseas continuar de todos modos? (s/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        echo "Abortando por seguridad."
        exit 1
    fi
elif [ "$HIGH" != "0" ]; then
    echo "⚠️  Se encontraron vulnerabilidades de nivel ALTO"
else
    echo "✓ No se encontraron vulnerabilidades críticas"
fi
echo ""

# Paso 4: Instalar dependencias (frozen lockfile)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Paso 4: Instalando dependencias (frozen lockfile)..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Ejecutando: pnpm install --frozen-lockfile --ignore-scripts"
echo ""
pnpm install --frozen-lockfile --ignore-scripts
echo ""
echo "✓ Dependencias instaladas"
echo ""

# Paso 5: Build de producción
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Paso 5: Compilando para producción..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
pnpm run build:prod
echo ""
echo "✓ Build completado"
echo ""

# Paso 6: Verificar output
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Paso 6: Verificando output..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
if [ -f "site/public/dist/index.bundle.js" ]; then
    SIZE=$(du -h "site/public/dist/index.bundle.js" | cut -f1)
    echo "✓ Bundle generado: site/public/dist/index.bundle.js ($SIZE)"

    # Copiar a directorio de dropin
    DROPIN_DIR="$PROJECT_ROOT/publisher-dropin"
    mkdir -p "$DROPIN_DIR"
    cp -r site/public/dist/* "$DROPIN_DIR/"
    echo "✓ Bundle copiado a: $DROPIN_DIR/"
else
    echo "✗ Error: No se generó el bundle"
    exit 1
fi
echo ""

echo "════════════════════════════════════════════════════════════"
echo "  ✓ Build completado exitosamente"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Para usar el dropin, actualiza docker-compose.yml:"
echo ""
echo "  volumes:"
echo "    - ./publisher-dropin:/home/wso2carbon/wso2am-4.5.0/repository/deployment/server/webapps/publisher/site/public/dist:ro"
echo ""
