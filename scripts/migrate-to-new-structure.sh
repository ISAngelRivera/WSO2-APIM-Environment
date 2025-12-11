#!/bin/bash
# =============================================================================
# Script de Migración a Nueva Estructura Multi-Entorno
# =============================================================================
# Migra la estructura antigua:
#   apis/{API}/{Ver}/revisions/rev-{N}/{API}-{Ver}/...
#
# A la nueva estructura:
#   apis/{API}/state.yaml
#   apis/{API}/{Ver}/rev-{N}/api.yaml
#   apis/{API}/{Ver}/rev-{N}/Definitions/swagger.yaml
#   apis/{API}/{Ver}/rev-{N}/Conf/api_meta.yaml
#   apis/{API}/{Ver}/rev-{N}/Conf/params.yaml
# =============================================================================

set -e

REPO_PATH="${1:-.}"

echo "=============================================="
echo "  Migración a Nueva Estructura Multi-Entorno"
echo "=============================================="
echo ""
echo "Repo: ${REPO_PATH}"
echo ""

# Verificar que existe la carpeta apis
if [ ! -d "${REPO_PATH}/apis" ]; then
    echo "ERROR: No existe carpeta apis/ en ${REPO_PATH}"
    exit 1
fi

# Función para convertir JSON a YAML (simplificado)
json_to_yaml() {
    local json_file="$1"
    local yaml_file="$2"

    if command -v yq &> /dev/null; then
        yq -P < "$json_file" > "$yaml_file"
    elif command -v python3 &> /dev/null; then
        python3 -c "
import json, sys
import yaml if 'yaml' in dir() else None

with open('$json_file', 'r') as f:
    data = json.load(f)

# Simple YAML output
def to_yaml(data, indent=0):
    result = ''
    prefix = '  ' * indent
    if isinstance(data, dict):
        for k, v in data.items():
            if isinstance(v, (dict, list)):
                result += f'{prefix}{k}:\n{to_yaml(v, indent+1)}'
            else:
                val = v if v is not None else ''
                if isinstance(val, str) and (':' in val or '#' in val or val == ''):
                    val = f'\"{val}\"'
                result += f'{prefix}{k}: {val}\n'
    elif isinstance(data, list):
        for item in data:
            if isinstance(item, (dict, list)):
                result += f'{prefix}-\n{to_yaml(item, indent+1)}'
            else:
                result += f'{prefix}- {item}\n'
    return result

print(to_yaml(data))
" > "$yaml_file"
    else
        # Fallback: copiar JSON como está
        cp "$json_file" "$yaml_file"
        echo "WARN: No se pudo convertir a YAML, copiado como JSON"
    fi
}

# Generar params.yaml template
generate_params_yaml() {
    local api_name="$1"
    local version="$2"
    local output_file="$3"
    local endpoint_url="$4"

    cat > "$output_file" << EOF
# =============================================================================
# ${api_name} ${version} - Configuración por Entorno
# =============================================================================
# Formato: WSO2 apictl params.yaml nativo
# =============================================================================

environments:
  # ---------------------------------------------------------------------------
  # UAT - Desarrollo/Testing
  # ---------------------------------------------------------------------------
  - name: uat
    configs:
      endpoints:
        production:
          url: ${endpoint_url:-https://api-uat.internal.company.com/placeholder}
          config:
            retryTimeOut: 2
            retryDelay: 500
            suspendDuration: 10000
            suspendMaxDuration: 30000

      security:
        production:
          enabled: false

      certs: []
      mutualSslCerts: []

      policies:
        - Gold

      deploymentEnvironments:
        - displayOnDevportal: true
          deploymentEnvironment: Default

  # ---------------------------------------------------------------------------
  # NFT - Pre-producción
  # ---------------------------------------------------------------------------
  - name: nft
    configs:
      endpoints:
        production:
          url: ${endpoint_url:-https://api-nft.internal.company.com/placeholder}
          config:
            retryTimeOut: 3
            retryDelay: 1000
            suspendDuration: 30000
            suspendMaxDuration: 60000

      security:
        production:
          enabled: false

      certs: []
      mutualSslCerts: []

      policies:
        - Platinum

      deploymentEnvironments:
        - displayOnDevportal: true
          deploymentEnvironment: Default

  # ---------------------------------------------------------------------------
  # PRO - Producción
  # ---------------------------------------------------------------------------
  - name: pro
    configs:
      endpoints:
        production:
          url: ${endpoint_url:-https://api.company.com/placeholder}
          config:
            retryTimeOut: 5
            retryDelay: 2000
            suspendDuration: 60000
            suspendMaxDuration: 300000

      security:
        production:
          enabled: false

      certs: []
      mutualSslCerts: []

      policies:
        - Unlimited

      deploymentEnvironments:
        - displayOnDevportal: true
          deploymentEnvironment: Default
EOF
}

# Generar state.yaml inicial
generate_state_yaml() {
    local api_name="$1"
    local output_file="$2"

    cat > "$output_file" << EOF
# =============================================================================
# ${api_name} - Estado de Deployments por Entorno
# =============================================================================
# ARCHIVO AUTO-GENERADO por GIT-Helix-Processor
# NO EDITAR MANUALMENTE
# =============================================================================

api_name: ${api_name}
last_updated: $(date -u +%Y-%m-%dT%H:%M:%SZ)

# Estado actual en cada entorno
environments:
  uat:
    version: null
    revision: null
    status: NOT_DEPLOYED

  nft:
    version: null
    revision: null
    status: NOT_DEPLOYED

  pro:
    version: null
    revision: null
    status: NOT_DEPLOYED

# Historial de operaciones
history: []
EOF
}

# Contador de migraciones
MIGRATED=0
ERRORS=0

# Iterar sobre cada API
for api_dir in "${REPO_PATH}/apis"/*/; do
    [ -d "$api_dir" ] || continue

    API_NAME=$(basename "$api_dir")
    [ "$API_NAME" == ".gitkeep" ] && continue

    echo "Procesando API: ${API_NAME}"

    # Crear state.yaml a nivel de API
    if [ ! -f "${api_dir}/state.yaml" ]; then
        generate_state_yaml "$API_NAME" "${api_dir}/state.yaml"
        echo "  ✓ Creado state.yaml"
    fi

    # Iterar sobre versiones
    for version_dir in "${api_dir}"/*/; do
        [ -d "$version_dir" ] || continue

        VERSION=$(basename "$version_dir")
        [ "$VERSION" == "state.yaml" ] && continue

        echo "  Versión: ${VERSION}"

        # Buscar estructura antigua: revisions/rev-N/{API}-{Ver}/
        OLD_REVISIONS_DIR="${version_dir}/revisions"

        if [ -d "$OLD_REVISIONS_DIR" ]; then
            for rev_dir in "${OLD_REVISIONS_DIR}"/rev-*/; do
                [ -d "$rev_dir" ] || continue

                REV_NAME=$(basename "$rev_dir")
                echo "    Revisión: ${REV_NAME}"

                # Nueva ubicación
                NEW_REV_DIR="${version_dir}/${REV_NAME}"

                # Buscar carpeta interna {API}-{Ver}/
                OLD_API_DIR="${rev_dir}/${API_NAME}-${VERSION}"

                if [ -d "$OLD_API_DIR" ]; then
                    # Crear nueva estructura
                    mkdir -p "${NEW_REV_DIR}/Definitions"
                    mkdir -p "${NEW_REV_DIR}/Conf"

                    # Mover/convertir api.json -> api.yaml
                    if [ -f "${OLD_API_DIR}/api.json" ]; then
                        # Por ahora copiamos el JSON, el workflow lo manejará
                        cp "${OLD_API_DIR}/api.json" "${NEW_REV_DIR}/api.yaml"
                        echo "      ✓ api.yaml (desde api.json)"

                        # Extraer endpoint URL para params
                        ENDPOINT_URL=$(grep -o '"url"[[:space:]]*:[[:space:]]*"[^"]*"' "${OLD_API_DIR}/api.json" | head -1 | sed 's/.*"url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
                    fi

                    # Mover swagger
                    if [ -f "${OLD_API_DIR}/Definitions/swagger.json" ]; then
                        cp "${OLD_API_DIR}/Definitions/swagger.json" "${NEW_REV_DIR}/Definitions/swagger.yaml"
                        echo "      ✓ swagger.yaml"
                    fi

                    # Mover api_meta.yaml
                    if [ -f "${OLD_API_DIR}/api_meta.yaml" ]; then
                        cp "${OLD_API_DIR}/api_meta.yaml" "${NEW_REV_DIR}/Conf/api_meta.yaml"
                        echo "      ✓ api_meta.yaml"
                    fi

                    # Generar params.yaml
                    generate_params_yaml "$API_NAME" "$VERSION" "${NEW_REV_DIR}/Conf/params.yaml" "$ENDPOINT_URL"
                    echo "      ✓ params.yaml (generado)"

                    # Copiar request.yaml si existe (trazabilidad)
                    if [ -f "${rev_dir}/request.yaml" ]; then
                        cp "${rev_dir}/request.yaml" "${NEW_REV_DIR}/Conf/request.yaml"
                        echo "      ✓ request.yaml (trazabilidad)"
                    fi

                    ((MIGRATED++))
                else
                    echo "      ✗ No se encontró estructura antigua en ${OLD_API_DIR}"
                    ((ERRORS++))
                fi
            done

            # Eliminar estructura antigua
            echo "    Eliminando estructura antigua..."
            rm -rf "$OLD_REVISIONS_DIR"
            echo "    ✓ Eliminado revisions/"
        else
            echo "    (Sin estructura antigua que migrar)"
        fi
    done

    echo ""
done

echo "=============================================="
echo "  Migración Completada"
echo "=============================================="
echo "  Revisiones migradas: ${MIGRATED}"
echo "  Errores: ${ERRORS}"
echo "=============================================="

if [ $ERRORS -gt 0 ]; then
    exit 1
fi
