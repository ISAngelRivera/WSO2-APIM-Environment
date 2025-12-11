#!/bin/bash
# =============================================================================
# Script de Migración a Estructura Simplificada (v3 - Sin Revisiones)
# =============================================================================
# Migra cualquier estructura anterior a:
#   apis/{APIName}/
#     state.yaml
#     {Version}/
#       api.yaml
#       Definitions/swagger.yaml
#       Conf/
#         api_meta.yaml
#         params.yaml
#         request.yaml
#
# Uso: ./migrate-to-new-structure.sh [ruta-repo]
# =============================================================================

set -e

REPO_PATH="${1:-.}"

echo "=============================================="
echo "  Migración a Estructura v3 (Sin Revisiones)"
echo "=============================================="
echo ""
echo "Repo: ${REPO_PATH}"
echo ""

# Verificar que existe la carpeta apis
if [ ! -d "${REPO_PATH}/apis" ]; then
    echo "ERROR: No existe carpeta apis/ en ${REPO_PATH}"
    exit 1
fi

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
# Última actualización: $(date -u +%Y-%m-%dT%H:%M:%SZ)
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
# ARCHIVO AUTO-GENERADO
# Se actualiza en cada registro
# =============================================================================

api_name: ${api_name}
last_updated: $(date -u +%Y-%m-%dT%H:%M:%SZ)

environments:
  uat:
    version: null
    status: NOT_DEPLOYED

  nft:
    version: null
    status: NOT_DEPLOYED

  pro:
    version: null
    status: NOT_DEPLOYED
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

    # Crear state.yaml a nivel de API si no existe
    if [ ! -f "${api_dir}/state.yaml" ]; then
        generate_state_yaml "$API_NAME" "${api_dir}/state.yaml"
        echo "  ✓ Creado state.yaml"
    fi

    # Iterar sobre versiones
    for version_dir in "${api_dir}"/*/; do
        [ -d "$version_dir" ] || continue

        VERSION=$(basename "$version_dir")
        # Saltar archivos y carpetas especiales
        [[ "$VERSION" == "state.yaml" || "$VERSION" == ".gitkeep" ]] && continue

        echo "  Versión: ${VERSION}"

        # =====================================================================
        # Caso 1: Estructura v2 con revisiones (apis/API/Ver/rev-N/)
        # =====================================================================
        HAS_REVISIONS=false
        for rev_candidate in "${version_dir}"/rev-*/; do
            if [ -d "$rev_candidate" ]; then
                HAS_REVISIONS=true
                break
            fi
        done

        if [ "$HAS_REVISIONS" == "true" ]; then
            echo "    Detectada estructura v2 con revisiones"

            # Tomar la última revisión
            LATEST_REV=$(ls -d "${version_dir}"/rev-*/ 2>/dev/null | sort -V | tail -1)

            if [ -n "$LATEST_REV" ] && [ -d "$LATEST_REV" ]; then
                REV_NAME=$(basename "$LATEST_REV")
                echo "    Usando revisión: ${REV_NAME}"

                # Mover contenido de la revisión al nivel de versión
                # Primero copiamos Definitions y Conf si existen
                if [ -d "${LATEST_REV}/Definitions" ]; then
                    mkdir -p "${version_dir}/Definitions"
                    cp -r "${LATEST_REV}/Definitions/"* "${version_dir}/Definitions/" 2>/dev/null || true
                    echo "    ✓ Definitions/"
                fi

                if [ -d "${LATEST_REV}/Conf" ]; then
                    mkdir -p "${version_dir}/Conf"
                    cp -r "${LATEST_REV}/Conf/"* "${version_dir}/Conf/" 2>/dev/null || true
                    echo "    ✓ Conf/"
                fi

                # Copiar api.yaml
                if [ -f "${LATEST_REV}/api.yaml" ]; then
                    cp "${LATEST_REV}/api.yaml" "${version_dir}/api.yaml"
                    echo "    ✓ api.yaml"
                fi

                # Eliminar todas las revisiones
                rm -rf "${version_dir}"/rev-*/
                echo "    ✓ Eliminadas revisiones"

                ((MIGRATED++))
            fi
        fi

        # =====================================================================
        # Caso 2: Estructura antigua (apis/API/Ver/revisions/rev-N/API-Ver/)
        # =====================================================================
        OLD_REVISIONS_DIR="${version_dir}/revisions"

        if [ -d "$OLD_REVISIONS_DIR" ]; then
            echo "    Detectada estructura antigua (revisions/)"

            # Tomar la última revisión
            LATEST_REV=$(ls -d "${OLD_REVISIONS_DIR}"/rev-*/ 2>/dev/null | sort -V | tail -1)

            if [ -n "$LATEST_REV" ] && [ -d "$LATEST_REV" ]; then
                REV_NAME=$(basename "$LATEST_REV")
                echo "    Usando revisión: ${REV_NAME}"

                # Buscar carpeta interna {API}-{Ver}/
                OLD_API_DIR="${LATEST_REV}/${API_NAME}-${VERSION}"

                if [ -d "$OLD_API_DIR" ]; then
                    # Crear estructura destino
                    mkdir -p "${version_dir}/Definitions"
                    mkdir -p "${version_dir}/Conf"

                    # Mover/copiar archivos
                    if [ -f "${OLD_API_DIR}/api.json" ]; then
                        cp "${OLD_API_DIR}/api.json" "${version_dir}/api.yaml"
                        echo "    ✓ api.yaml (desde api.json)"
                    fi

                    if [ -f "${OLD_API_DIR}/Definitions/swagger.json" ]; then
                        cp "${OLD_API_DIR}/Definitions/swagger.json" "${version_dir}/Definitions/swagger.yaml"
                        echo "    ✓ swagger.yaml"
                    elif [ -f "${OLD_API_DIR}/Definitions/swagger.yaml" ]; then
                        cp "${OLD_API_DIR}/Definitions/swagger.yaml" "${version_dir}/Definitions/swagger.yaml"
                        echo "    ✓ swagger.yaml"
                    fi

                    if [ -f "${OLD_API_DIR}/api_meta.yaml" ]; then
                        cp "${OLD_API_DIR}/api_meta.yaml" "${version_dir}/Conf/api_meta.yaml"
                        echo "    ✓ api_meta.yaml"
                    fi

                    # Extraer endpoint URL para params
                    ENDPOINT_URL=""
                    if [ -f "${OLD_API_DIR}/api.json" ]; then
                        ENDPOINT_URL=$(grep -o '"url"[[:space:]]*:[[:space:]]*"[^"]*"' "${OLD_API_DIR}/api.json" | head -1 | sed 's/.*"url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' 2>/dev/null || true)
                    fi

                    # Generar params.yaml si no existe
                    if [ ! -f "${version_dir}/Conf/params.yaml" ]; then
                        generate_params_yaml "$API_NAME" "$VERSION" "${version_dir}/Conf/params.yaml" "$ENDPOINT_URL"
                        echo "    ✓ params.yaml (generado)"
                    fi

                    # Copiar request.yaml si existe
                    if [ -f "${LATEST_REV}/request.yaml" ]; then
                        cp "${LATEST_REV}/request.yaml" "${version_dir}/Conf/request.yaml"
                        echo "    ✓ request.yaml"
                    fi

                    ((MIGRATED++))
                else
                    echo "    ✗ No se encontró estructura en ${OLD_API_DIR}"
                    ((ERRORS++))
                fi
            fi

            # Eliminar estructura antigua
            echo "    Eliminando estructura antigua..."
            rm -rf "$OLD_REVISIONS_DIR"
            echo "    ✓ Eliminado revisions/"
        fi

        # =====================================================================
        # Caso 3: Ya tiene estructura correcta - solo verificar params.yaml
        # =====================================================================
        if [ -f "${version_dir}/api.yaml" ] && [ ! -f "${version_dir}/Conf/params.yaml" ]; then
            mkdir -p "${version_dir}/Conf"
            generate_params_yaml "$API_NAME" "$VERSION" "${version_dir}/Conf/params.yaml"
            echo "    ✓ params.yaml (generado para estructura existente)"
            ((MIGRATED++))
        fi
    done

    echo ""
done

echo "=============================================="
echo "  Migración Completada"
echo "=============================================="
echo "  Versiones migradas: ${MIGRATED}"
echo "  Errores: ${ERRORS}"
echo "=============================================="

if [ $ERRORS -gt 0 ]; then
    exit 1
fi
