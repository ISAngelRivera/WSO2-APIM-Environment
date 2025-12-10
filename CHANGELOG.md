# Changelog - WSO2 APIOps Environment

## [2025-12-10] - Squash de Repositorio y Fix Runner

### Changed
- **Git Squash**: Consolidado historial de commits en un único commit limpio para el POC
- **Commit final**: `feat: POC completo portable` incluye todos los archivos necesarios

### Fixed
- **github-runner no iniciaba**: Tras el squash, el contenedor del runner no se construyó automáticamente
  - **Causa**: Al ejecutar `docker compose up -d`, WSO2 tardó en estar healthy y el runner no se inició
  - **Solución**: `docker compose up -d github-runner --build`
- **Workflows legacy causaban errores**: `register-api-uat.yml` y `on-request-pr.yml` eran archivos obsoletos
  - **Causa**: Workflows antiguos que ya no se usaban pero seguían en el repo
  - **Solución**: Eliminados de GIT-Helix-Processor
- **APIs sin desplegar**: Las APIs existían pero no tenían revisiones desplegadas en el Gateway
  - **Causa**: Al reiniciar WSO2, las revisiones desplegadas se perdieron
  - **Solución**: Script para crear y desplegar revisiones automáticamente

### Notes
- Los API IDs son dinámicos y cambian cada vez que se recrean las APIs
- El Publisher obtiene el API ID correcto en tiempo real, por lo que esto no afecta al flujo normal
- Flujo E2E verificado y funcionando correctamente tras las correcciones

## [2025-12-09] - Flujo End-to-End Completo

### Added
- **Polling en dos fases**: El Publisher ahora monitorea ambos workflows (process-api-request + on-helix-approval)
- **Mensajes de progreso específicos**: "Creando solicitud CRQ...", "Creando PR y realizando merge...", "Realizando merge automático..."
- **Función extractHelixError**: Extracción centralizada de errores de Helix-Processor

### Changed
- **on-helix-approval.yml**: Cambiado de `--auto --squash` a `--squash --delete-branch` para merge directo
- **UATRegistration.jsx**: Refactorizado pollHelixProcessor para soportar dos fases
- **maxAttempts**: Aumentado de 40 a 60 para dar tiempo a los dos workflows

### Fixed
- El Publisher ahora muestra "API registrada correctamente" solo cuando el merge está completo
- Eliminada dependencia de branch protection rules para auto-merge

## [2025-12-09] - Fix Simulación Helix

### Fixed
- **repository_dispatch**: Cambiado de GITHUB_TOKEN a GIT_HELIX_PAT
- **JSON formatting**: Cambiado de `gh api` a `curl` para enviar client_payload correctamente
- Añadido secret GIT_HELIX_PAT en GIT-Helix-Processor

## [2025-12-09] - Fix Workflows Rápidos

### Fixed
- Detección de workflows que terminan antes de que el polling los encuentre
- Si el run ya está completado cuando se encuentra, se procesa inmediatamente
- Correlación por requestId en lugar de timestamp (más confiable)

### Changed
- **getWorkflowJobs**: Acepta parámetro repoOverride para consultar Helix-Processor
- Mensajes de error específicos para cada tipo de fallo

## [2025-12-09] - Mejoras Build y Setup

### Fixed
- **build-publisher.sh**: Ya no sobrescribe index.jsp al compilar
- **setup-all.sh**: Usa create-test-apis.sh (9 APIs) en lugar de create-all-sample-apis.sh (15 APIs)
- **index.jsp**: Siempre incluye apiops-config.js

## [2025-12-09] - Branch Names Únicos

### Fixed
- Branch names ahora incluyen sufijo único del requestId
- Formato: `api/{API}-{VERSION}-{REVISION}-{SUFFIX}`
- Previene conflictos al registrar la misma API múltiples veces

## [2025-12-07] - Arquitectura con Webhook

### Added
- **on-helix-approval.yml**: Nuevo workflow para recibir webhooks de Helix
- **Sistema de Issues**: Cola de solicitudes con label `pending-helix`
- **Artifacts**: Export de API guardado por 30 días
- **AUTO_APPROVE flag**: Simulación automática para testing

### Changed
- **process-api-request.yml**: Reescrito para crear Issue en lugar de PR directamente
- El workflow termina rápido (~15s) en lugar de esperar a Helix

## [2025-12-06] - Sistema de Subdominios

### Added
- **repo-config.yaml**: Configuración de subdominios y repositorios
- **Validación de subdominio**: En WSO2-Processor y GIT-Helix-Processor
- **Estructura de carpetas**: apis/{API}/{VERSION}/revisions/{REV}/

### Changed
- Las APIs se organizan por subdominio (área de negocio)
- Límite de 4 versiones y 4 revisiones por API

## [2025-12-05] - Componente UATRegistration

### Added
- **UATRegistration.jsx**: Componente React para registro en UAT
- **Polling de GitHub Actions**: Monitoreo en tiempo real del progreso
- **Estados visuales**: Validando, Solicitando CRQ, Registrando, Registrado, Error

## [2025-12-04] - Self-Hosted Runner

### Added
- **github-runner/**: Dockerfile y entrypoint para runner en Docker
- Acceso a WSO2 via red Docker (wso2-apim:9443)
- Labels: self-hosted, linux, apiops

## [2025-12-03] - Setup Inicial

### Added
- **docker-compose.yml**: WSO2 APIM 4.5.0 + GitHub Runner
- **scripts/**: setup-all.sh, create-test-users.sh, create-test-apis.sh
- **publisher-dropin/**: Sistema de dropin para personalizar Publisher
- **apiops-config.js**: Configuración externa de GitHub
