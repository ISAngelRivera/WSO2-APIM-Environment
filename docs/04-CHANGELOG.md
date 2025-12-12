# Changelog

Historial de cambios del proyecto APIOps.

---

## [2025-12-12] - Renombrado de Repositorios

### Changed
- Repositorios renombrados a nomenclatura profesional `apim-*`:
  - `WSO2-APIM-Environment` -> `apim-local-env`
  - `WSO2-Processor` -> `apim-exporter-wso2`
  - `GIT-Helix-Processor` -> `apim-apiops-controller`
  - `RRHH-Empleados` -> `apim-domain-rrhh`
  - `Finanzas-Pagos` -> `apim-domain-finanzas`
- Actualizadas todas las referencias en workflows y configuraciones
- Documentacion optimizada (4 documentos esenciales)

---

## [2025-12-11] - Estructura v3 (Sin Revisiones)

### Changed
- Eliminadas revisiones de la estructura de carpetas
- Cada registro SOBRESCRIBE la version (mas simple)
- Estructura simplificada: `apis/{API}/{Version}/`

### Reasoning
- Hard Rock y wso2-cicd no usan revisiones
- 5,000 carpetas vs 15,000 (para 2500 APIs)
- WSO2 gestiona revisiones internamente

---

## [2025-12-11] - Estructura Multi-Entorno

### Added
- `params.yaml` con configuracion UAT/NFT/PRO
- `state.yaml` para tracking de deployments
- Workflow `promote-api.yml` para promociones
- Script `migrate-to-new-structure.sh`

### Changed
- Estructura de repos de dominio adaptada

---

## [2025-12-10] - Fix Runner y Squash

### Fixed
- Runner no iniciaba tras squash
- Workflows legacy eliminados
- APIs sin desplegar tras reinicio

---

## [2025-12-09] - Flujo E2E Completo

### Added
- Polling en dos fases (apim-exporter-wso2 + on-helix-approval)
- Mensajes de progreso especificos
- Sistema de Issues como cola
- Artifacts para persistencia (30 dias)
- Auto-merge de PRs

### Fixed
- Errores de simulacion Helix
- Deteccion de workflows rapidos

---

## [2025-12-07] - Arquitectura con Webhook

### Added
- `on-helix-approval.yml` para webhooks
- Flag `AUTO_APPROVE` para testing
- Sistema de Issues con label `pending-helix`

---

## [2025-12-06] - Sistema de Subdominios

### Added
- `repo-config.yaml` con mapeo subdominios
- Validacion de subdominio en workflows
- Estructura: `apis/{API}/{VERSION}/`

---

## [2025-12-05] - Componente UATRegistration

### Added
- `UATRegistration.jsx` (1,385 lineas)
- Stepper visual de 4 pasos
- Polling de GitHub Actions
- Persistencia en localStorage
- Dialogo de cancelacion

---

## [2025-12-04] - Self-Hosted Runner

### Added
- Dockerfile para runner en Docker
- Acceso a WSO2 via red Docker
- Labels: self-hosted, linux, apiops

---

## [2025-12-03] - Setup Inicial

### Added
- `docker-compose.yml` con WSO2 APIM 4.5.0
- Scripts de automatizacion
- Sistema de dropins para Publisher
- `apiops-config.js` para configuracion
