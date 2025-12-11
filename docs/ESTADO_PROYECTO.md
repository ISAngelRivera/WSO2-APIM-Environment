# Estado del Proyecto APIOps - WSO2 APIM

**Última actualización:** 2025-12-11 (estructura multi-entorno UAT/NFT/PRO)
**Versión WSO2 APIM:** 4.5.0

## Objetivo Principal

Crear un sistema APIOps enterprise que integre:
1. **WSO2 API Manager** - Gestión de APIs
2. **Git (GitHub)** - Versionado de definiciones de API + Backend (GitHub Actions)
3. **Helix (ITSM)** - Gestión de cambios (CRQ)
4. **Multi-Entorno** - Promoción UAT → NFT → PRO

### Arquitectura GitOps con Webhook de Helix (NUEVO 2025-12-07)

```
┌─────────────────────────────────────────────────────────────────────────┐
│ FASE 1: Solicitud (instantánea ~10s)                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────────┐                                               │
│  │  Publisher Portal   │                                               │
│  │  (UATRegistration)  │                                               │
│  └─────────┬───────────┘                                               │
│            │ workflow_dispatch                                          │
│            ▼                                                            │
│  ┌─────────────────────┐                                               │
│  │   WSO2-Processor    │  ← Self-hosted runner en Docker               │
│  │  - Exporta API      │    Accede a WSO2 via red Docker               │
│  │  - Valida subdom.   │                                               │
│  │  - Obtiene revisión │                                               │
│  └─────────┬───────────┘                                               │
│            │ workflow_dispatch                                          │
│            ▼                                                            │
│  ┌─────────────────────┐                                               │
│  │ GIT-Helix-Processor │                                               │
│  │  - Crea Issue       │  ← Cola de solicitudes pendientes             │
│  │  - Guarda artifact  │  ← Export de API (30 días)                    │
│  │  - Crea CRQ Helix   │  ← Simulado (futuro: API real)                │
│  │  - Termina ✓        │  ← NO crea PR directamente                    │
│  └─────────────────────┘                                               │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│ FASE 2: Aprobación (cuando Helix aprueba - instantáneo con AUTO_APPROVE)│
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────────┐                                               │
│  │    Helix ITSM       │                                               │
│  │  (CAB aprueba CRQ)  │                                               │
│  └─────────┬───────────┘                                               │
│            │ repository_dispatch (webhook)                              │
│            ▼                                                            │
│  ┌─────────────────────┐                                               │
│  │ on-helix-approval   │  ← Workflow de aprobación                     │
│  │  - Busca Issue      │                                               │
│  │  - Lee metadata     │                                               │
│  │  - Si APPROVED:     │                                               │
│  │    → Crea PR        │  ← En repo del subdominio                     │
│  │    → Merge directo  │  ← --squash --delete-branch                   │
│  │    → Cierra Issue   │  ← label: approved                            │
│  │  - Si REJECTED:     │                                               │
│  │    → Cierra Issue   │  ← label: rejected                            │
│  └─────────────────────┘                                               │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

**Decisión clave:** GitHub ES el backend. No hay servidor adicional.

### Ventajas del Nuevo Flujo

| Aspecto | Flujo Anterior | Flujo Nuevo |
|---------|----------------|-------------|
| **Espera Helix** | Workflow colgado | Workflow termina rápido |
| **Cola de solicitudes** | No había | Issues con label `pending-helix` |
| **Escalabilidad** | Polling constante | Webhook instantáneo |
| **Trazabilidad** | Solo logs | Issues + artifacts + PRs |
| **Resiliencia** | Si falla, se pierde | Artifacts guardados 30 días |

## Sistema de Subdominios

### Concepto

Las APIs se organizan por **subdominio** (área de negocio) no por repositorio Git.
El mapeo backend→subdominio se define en `repo-config.yaml` en GIT-Helix-Processor.

### Estructura de Carpetas (v2 - Multi-Entorno)

```
{RepoSubdominio}/               # Ej: ISAngelRivera/Finanzas-Pagos
├── apis/
│   ├── AccountAPI/             # Nombre de la API
│   │   ├── state.yaml          # Estado por entorno (auto-generated)
│   │   ├── 1.0.0/              # Versión
│   │   │   └── rev-1/          # Revisión (inmutable)
│   │   │       ├── api.yaml    # Definición API
│   │   │       ├── Definitions/
│   │   │       │   └── swagger.yaml
│   │   │       └── Conf/
│   │   │           ├── api_meta.yaml    # Metadata
│   │   │           ├── params.yaml      # Config UAT/NFT/PRO
│   │   │           └── request.yaml     # Trazabilidad
│   │   └── 2.0.0/
│   │       └── rev-1/
│   └── PaymentAPI/
```

**Ventajas de la nueva estructura:**
- Cada revisión es un snapshot inmutable
- params.yaml contiene configuración de TODOS los entornos
- state.yaml permite saber qué revisión está en cada entorno
- 100% trazabilidad: qué revisión con qué config se desplegó

**Límites:**
- Máximo 4 versiones por API (las antiguas se rotan/eliminan)
- Máximo 4 revisiones por versión (las antiguas se rotan/eliminan)

### repo-config.yaml
```yaml
subdominios:
  finanzas-pagos:
    description: "APIs del dominio de Finanzas y Pagos"
    git_repo: "ISAngelRivera/Finanzas-Pagos"
    owners:
      - "team-finanzas@company.com"

  rrhh-empleados:
    description: "APIs del dominio de RRHH y Empleados"
    git_repo: "ISAngelRivera/RRHH-Empleados"
    owners:
      - "team-rrhh@company.com"

  informatica-devops:
    description: "APIs del dominio de Informatica y DevOps"
    git_repo: "ISAngelRivera/Informatica-DevOps"
    owners:
      - "team-devops@company.com"
```

## Self-Hosted Runner en Docker

### Por qué
- GitHub Actions cloud NO puede acceder a WSO2 en localhost:9443
- El runner Docker se conecta via red Docker (`wso2-apim:9443`)
- Portabilidad: funciona igual en Mac, Windows, Linux

### Configuración
```yaml
# docker-compose.yml
github-runner:
  build: ./github-runner
  environment:
    - GITHUB_TOKEN=${GITHUB_TOKEN}
    - GITHUB_OWNER=ISAngelRivera
    - GITHUB_REPO=WSO2-Processor
    - RUNNER_LABELS=self-hosted,linux,apiops
  depends_on:
    wso2-apim:
      condition: service_healthy
```

## Estado Actual

### Completado

1. **Componente React UATRegistration** ✅
2. **Build del Publisher con dropin** ✅
3. **Configuración Externa (apiops-config.js)** ✅
4. **WSO2-Processor con workflow dispatch** ✅
5. **GIT-Helix-Processor con linters** ✅
6. **Self-hosted runner en Docker** ✅
7. **Sistema de subdominios** ✅
8. **Script create-all-sample-apis.sh** ✅
9. **Estructura apis/NombreAPI/version** ✅
10. **RequestId para escalabilidad** ✅
11. **Usuario real en registro UAT** ✅
12. **Revisión desplegada obligatoria** ✅
13. **Usuarios de prueba automáticos (dev1, dev2)** ✅
14. **Fix index.jsp para cargar apiops-config.js** ✅
15. **Fix revision ID (número vs UUID)** ✅
16. **Manejo de solicitudes duplicadas** ✅
17. **Flujo con webhook de Helix** ✅ (2025-12-07)
    - `process-api-request.yml` reescrito: crea Issue + guarda artifact
    - `on-helix-approval.yml` nuevo: recibe webhook, crea PR
    - `AUTO_APPROVE` flag para testing (simula webhook automático)
    - `scripts/simulate-helix-approval.sh` para testing manual
18. **Fix push duplicados en ramas** ✅ (2025-12-09)
    - Branch name ahora incluye sufijo único del requestId
    - Formato: `api/{API}-{VERSION}-{REVISION}-{SUFFIX}`
    - Ejemplo: `api/EmployeeAPI-1.0.0-rev-1-v5`
19. **Mejoras UI Publisher** ✅ (2025-12-09)
    - Botón "Registrar en UAT" se deshabilita durante proceso (evita duplicados)
    - Eliminado botón "Resetear" innecesario
    - Diálogo de cancelación mejorado con lista de consecuencias
20. **Repo RRHH-Empleados** ✅ (2025-12-09)
    - Nuevo subdominio `rrhh-empleados`
    - APIs de prueba: EmployeeAPI, DepartmentAPI
21. **Workflows con ubuntu-latest** ✅ (2025-12-09)
    - GIT-Helix-Processor ya no necesita self-hosted runner
    - Solo WSO2-Processor requiere runner Docker (acceso a WSO2)
22. **Labels de Issues configurados** ✅ (2025-12-09)
    - `pending-helix`: solicitudes esperando aprobación
    - `approved`: aprobadas por Helix
    - `rejected`: rechazadas por Helix
23. **Lifecycle estándar (sin botón Register UAT)** ✅ (2025-12-09)
    - Eliminado el botón "Register UAT" del lifecycle de WSO2
    - El registro en UAT se hace SOLO via el componente React UATRegistration
    - Archivos modificados: `lifecycle.json`, `APILifeCycle.xml`, `configure-lifecycle.sh`
24. **Detección mejorada de errores en Publisher** ✅ (2025-12-09)
    - Polling de Helix-Processor usa requestId para correlación (no timestamp)
    - Detección de subdominio inválido con mensaje específico
    - Fix para workflows rápidos: si el run ya está completado cuando se encuentra, se procesa inmediatamente
    - Errores específicos para: API no desplegada, subdominio faltante, subdominio inválido
25. **Script create-test-apis.sh para 9 APIs** ✅ (2025-12-09)
    - setup-all.sh ahora usa create-test-apis.sh (9 APIs) en lugar de create-all-sample-apis.sh (15 APIs)
    - APIs de prueba organizadas en subdominios: rrhh-empleados, finanzas-pagos
    - Incluye TestAPI sin subdominio para probar validación
26. **Script build-publisher.sh mejorado** ✅ (2025-12-09)
    - Ya no sobrescribe index.jsp al compilar
    - Actualiza solo el hash del bundle manteniendo personalizaciones
    - Auto-añade apiops-config.js si falta
27. **Fix simulación Helix (repository_dispatch)** ✅ (2025-12-09)
    - Cambiado `GITHUB_TOKEN` por `GIT_HELIX_PAT` en process-api-request.yml
    - Añadido secret `GIT_HELIX_PAT` en GIT-Helix-Processor
    - Auto-aprobación ahora funciona correctamente
28. **Auto-merge directo en on-helix-approval** ✅ (2025-12-09)
    - Cambiado de `--auto --squash` a `--squash --delete-branch`
    - Ya no requiere branch protection rules
    - Merge inmediato tras crear PR (Helix ya aprobó, no necesita otra revisión)
29. **Polling en dos fases en Publisher** ✅ (2025-12-09)
    - Fase 1: Poll `process-api-request.yml` (crea Issue + CRQ)
    - Fase 2: Poll `on-helix-approval.yml` (crea PR + merge)
    - El Publisher muestra "API registrada correctamente" solo cuando el merge está completo
    - Mensajes de progreso específicos para cada fase
30. **Flujo end-to-end completamente funcional** ✅ (2025-12-09)
    - Click en "Registrar en UAT" → Validaciones → Issue → Simula Helix → PR → Merge → Éxito
    - Tiempo total: ~30-45 segundos
    - Escalable para 2500+ APIs gracias a requestId único
31. **Estructura multi-entorno (UAT/NFT/PRO)** ✅ (2025-12-11)
    - Nueva estructura de carpetas: `apis/{API}/{Ver}/{rev-N}/`
    - `state.yaml` a nivel de API para tracking de deployments por entorno
    - `params.yaml` con configuración específica por entorno (endpoints, policies, retry)
    - Script de migración `migrate-to-new-structure.sh`
    - Repositorios migrados: RRHH-Empleados, Finanzas-Pagos
32. **Workflow on-helix-approval.yml v2** ✅ (2025-12-11)
    - Genera estructura multi-entorno automáticamente
    - Crea/actualiza `state.yaml` con historial de operaciones
    - Genera `params.yaml` con 3 entornos configurados
    - Extrae action y environment del Issue metadata
33. **Workflow promote-api.yml** ✅ (2025-12-11)
    - Nuevo workflow para promoción entre entornos
    - Soporta flujo UAT → NFT → PRO
    - Valida estado actual antes de promocionar
    - Crea Issue de tracking para deployments a PRO
34. **Labels de entorno y acción** ✅ (2025-12-11)
    - `env:uat`, `env:nft`, `env:pro` - Para identificar entorno target
    - `action:deploy`, `action:promote`, `action:rollback` - Para identificar operación
35. **18 pruebas E2E automatizadas** ✅ (2025-12-11)
    - Infraestructura (WSO2, Runner, OAuth)
    - APIs de ejemplo (subdominios)
    - Validaciones de negocio (sin subdominio, sin deployment)
    - Flujo UAT completo
    - Usuarios de prueba
    - Integración Git

### Usuarios del Sistema

| Usuario | Password | Rol | Descripción |
|---------|----------|-----|-------------|
| admin | admin | Administrador | Usuario por defecto de WSO2 |
| dev1 | Dev1pass! | Internal/creator, Internal/publisher | Desarrollador de prueba 1 |
| dev2 | Dev2pass! | Internal/creator, Internal/publisher | Desarrollador de prueba 2 |

**Nota:** Los passwords cumplen con la política de WSO2 (mayúscula, minúscula, número, símbolo).

### Validaciones de Registro UAT

| Validación | Dónde se valida | Error si falla |
|------------|-----------------|----------------|
| **Subdominio configurado** | WSO2-Processor | "La API no tiene configurado el campo 'subdominio' en Additional Properties" |
| **Subdominio válido** | GIT-Helix-Processor | "El subdominio configurado no existe en el sistema" |
| **API desplegada** | WSO2-Processor | "La API no tiene ninguna revisión desplegada en un Gateway" |

### Pendiente (Futuras Mejoras)

1. **Integración real con Helix ITSM**
   - Actualmente simulado con `AUTO_APPROVE=true`
   - Requiere: API de Helix + configuración de webhook
   - El flujo ya está preparado para recibir webhooks

2. **Gestión de tokens por usuario**
   - Actualmente: token compartido en `apiops-config.js`
   - Opciones: GitHub App + Key Manager, OAuth federation
   - Documentado para implementación futura

3. **Linters especializados**
   - Spectral para OpenAPI
   - Validaciones de seguridad
   - Políticas de empresa

4. **Deployment real a WSO2 por entorno**
   - Integración con apictl para deploy real
   - Conexión a instancias WSO2 de UAT/NFT/PRO
   - Actualización de state.yaml con status DEPLOYED

## Workflows de GitHub Actions

### WSO2-Processor

| Workflow | Archivo | Descripción |
|----------|---------|-------------|
| Receive UAT Request | `receive-uat-request.yml` | Extrae API de WSO2, valida, envía a Helix-Processor |

### GIT-Helix-Processor

| Workflow | Archivo | Descripción |
|----------|---------|-------------|
| Process API Request | `process-api-request.yml` | Crea Issue, guarda artifact, simula CRQ |
| On Helix Approval | `on-helix-approval.yml` | Recibe webhook, crea estructura multi-entorno, PR en subdominio |
| Promote API | `promote-api.yml` | Promociona API entre entornos (UAT→NFT→PRO) |

### Flujo Detallado

```
1. Usuario hace clic en "Registrar en UAT"
   ├── Publisher genera requestId único (REQ-{api}-{timestamp}-{random})
   └── Publisher inicia polling de WSO2-Processor

2. WSO2-Processor (receive-uat-request.yml) [~10s]
   ├── Valida que API esté desplegada
   ├── Exporta API con apictl
   ├── Valida que tenga subdominio configurado
   ├── Obtiene número de revisión desplegada
   └── Dispara Helix-Processor via workflow_dispatch

3. Helix-Processor (process-api-request.yml) [~15s]
   ├── Valida subdominio existe en repo-config.yaml
   ├── Crea Issue con label "pending-helix"
   ├── Guarda artifact (export de API, 30 días)
   ├── Simula creación de CRQ en Helix
   ├── Si AUTO_APPROVE=true: envía repository_dispatch
   └── Publisher pasa a Fase 2 del polling

4. Helix Approval (on-helix-approval.yml) [~15s]
   ├── Recibe webhook (repository_dispatch)
   ├── Busca Issue por requestId
   ├── Lee metadata del Issue (api, version, subdominio, etc.)
   ├── Descarga artifact con export de API
   ├── Clona repo del subdominio
   ├── Crea branch: api/{API}-{VERSION}-{REV}-{SUFFIX}
   ├── Copia archivos de la API
   ├── Crea commit y push
   ├── Crea PR con detalles completos
   ├── Merge directo (--squash --delete-branch)
   ├── Cierra Issue con label "approved"
   └── Publisher muestra "API registrada correctamente"

Tiempo total: ~30-45 segundos
```

## Arquitectura de Archivos

```
WSO2-APIM-Environment/
├── docker-compose.yml          # WSO2 + GitHub Runner
├── .env                        # Variables (GITHUB_TOKEN, etc.)
├── github-runner/              # Self-hosted runner
│   ├── Dockerfile
│   └── entrypoint.sh
├── publisher-dropin/           # Bundle compilado del Publisher
├── publisher-dropin-pages/     # index.jsp
│   └── index.jsp               # IMPORTANTE: incluye apiops-config.js
├── publisher-config/
│   └── apiops-config.js        # Token de GitHub y configuración
├── scripts/
│   ├── create-all-sample-apis.sh  # Crear APIs de prueba
│   ├── create-test-users.sh       # Crear usuarios dev1, dev2
│   ├── setup-all.sh               # Configuración completa
│   ├── configure-lifecycle.sh     # Lifecycle con "Register UAT"
│   ├── verify-lifecycle.sh        # Verificar lifecycle
│   └── wait-for-apim.sh
└── docs/
    └── ESTADO_PROYECTO.md      # Este archivo
```

## Procedimientos de Desarrollo

### Reset completo (recomendado para probar cambios)

```bash
# 1. Eliminar todo incluyendo volúmenes
docker compose down -v

# 2. Reiniciar
docker compose up -d

# 3. Configurar todo (usuarios + lifecycle + APIs)
./scripts/setup-all.sh
```

### Después de modificar el código del Publisher

```bash
# 1. Compilar el Publisher
cd wso2-source/apim-apps/portals/publisher/src/main/webapp
pnpm run build:prod

# 2. Copiar los bundles
rm -rf ../../../../../../publisher-dropin/*
cp -r site/public/dist/* ../../../../../../publisher-dropin/

# 3. Actualizar el hash en index.jsp
ls site/public/dist/index.*.bundle.js
# Editar publisher-dropin-pages/index.jsp con el nuevo hash

# 4. Reiniciar WSO2
docker stop wso2-apim && docker start wso2-apim
```

### Simular webhook de Helix (testing manual)

```bash
# Aprobar una solicitud pendiente
./scripts/simulate-helix-approval.sh REQ-xxx-xxx APPROVED

# Rechazar una solicitud
./scripts/simulate-helix-approval.sh REQ-xxx-xxx REJECTED
```

### Desactivar auto-aprobación (simular flujo real)

En `GIT-Helix-Processor/.github/workflows/process-api-request.yml`:
```yaml
env:
  AUTO_APPROVE: "false"  # Cambiar de "true" a "false"
```

Con esto, las solicitudes quedarán en Issues con label `pending-helix` esperando webhook.

## Comandos Útiles

```bash
# Iniciar todo (WSO2 + Runner)
docker compose up -d

# Ver logs del runner
docker logs -f github-runner

# Configuración inicial completa
./scripts/setup-all.sh

# Solo crear usuarios de prueba
./scripts/create-test-users.sh

# Solo crear APIs de prueba
./scripts/create-all-sample-apis.sh

# Reiniciar solo WSO2 (preserva datos)
docker stop wso2-apim && docker start wso2-apim

# Reset completo (BORRA TODAS LAS APIs Y USUARIOS)
docker compose down -v
docker compose up -d
./scripts/setup-all.sh

# Ver Issues pendientes de Helix
gh issue list --repo ISAngelRivera/GIT-Helix-Processor --label pending-helix
```

## URLs de Acceso

- **Publisher Portal:** https://localhost:9443/publisher
- **DevPortal:** https://localhost:9443/devportal
- **Carbon Console:** https://localhost:9443/carbon
- **WSO2-Processor Actions:** https://github.com/ISAngelRivera/WSO2-Processor/actions
- **Helix-Processor Issues:** https://github.com/ISAngelRivera/GIT-Helix-Processor/issues
- **Helix-Processor Actions:** https://github.com/ISAngelRivera/GIT-Helix-Processor/actions

## Repositorios del Proyecto

| Repositorio | URL | Propósito | Runner |
|-------------|-----|-----------|--------|
| WSO2-APIM-Environment | (local) | Entorno de desarrollo, Publisher, Runner | - |
| WSO2-Processor | github.com/ISAngelRivera/WSO2-Processor | Extrae APIs de WSO2 | self-hosted (Docker) |
| GIT-Helix-Processor | github.com/ISAngelRivera/GIT-Helix-Processor | Cola de solicitudes, webhooks, repo-config | ubuntu-latest |
| Finanzas-Pagos | github.com/ISAngelRivera/Finanzas-Pagos | Repo subdominio finanzas | - |
| RRHH-Empleados | github.com/ISAngelRivera/RRHH-Empleados | Repo subdominio RRHH | - |
| Informatica-DevOps | github.com/ISAngelRivera/Informatica-DevOps | Repo subdominio informática | - |

## Lecciones Aprendidas

### Flujo con Webhook vs Polling

**Problema anterior:** El workflow se quedaba esperando a que Helix aprobara, lo que no es viable porque:
- Helix puede tardar horas/días en aprobar
- GitHub Actions tiene timeout de 6 horas
- No es escalable para múltiples solicitudes

**Solución:** Arquitectura basada en webhooks:
1. El workflow termina rápido (solo guarda la solicitud)
2. Helix envía webhook cuando aprueba/rechaza
3. Otro workflow procesa el webhook y crea la PR

### Issues como Cola de Solicitudes

Usar GitHub Issues para la cola de solicitudes pendientes tiene ventajas:
- **Visible:** Cualquiera puede ver las solicitudes pendientes
- **Auditable:** Historial completo de cada solicitud
- **Gratis:** No requiere base de datos externa
- **Buscable:** Fácil encontrar por requestId, API, usuario

### Artifacts para Persistencia

El export de la API se guarda como artifact por 30 días. Esto permite:
- Reintentar si el webhook falla
- Inspeccionar el contenido de la solicitud
- No depender de que WSO2 siga disponible cuando Helix apruebe

### index.jsp debe incluir apiops-config.js

**Bug resuelto:** El token de GitHub no se cargaba porque `index.jsp` no tenía el `<script>` para cargar `apiops-config.js`.

```jsp
<!-- IMPORTANTE: Esta línea debe estar en index.jsp -->
<script src="<%= context%>/site/public/conf/apiops-config.js"></script>
```

### Revision ID es Número, no UUID

**Bug resuelto:** El ID de revisión en WSO2 es un UUID (`53850a53-...`), pero necesitamos el número (`1`, `2`, `3`).

```bash
# Correcto: extraer número de displayName "Revision N"
LATEST_REV_NUM=$(echo "$REVISIONS" | jq -r '
  .list
  | sort_by(.displayName | capture("Revision (?<n>[0-9]+)") | .n | tonumber)
  | last
  | .displayName
  | capture("Revision (?<n>[0-9]+)")
  | .n
')
```

### Branch Names Únicos (2025-12-09)

**Bug resuelto:** Al registrar la misma API+versión+revisión múltiples veces, el push fallaba con "non-fast-forward" porque la rama ya existía.

**Solución:** Incluir sufijo único del requestId en el nombre de la rama:
```bash
# Antes (colisionaba):
api/AccountAPI-2.0.1-rev-1

# Ahora (único):
api/AccountAPI-2.0.1-rev-1-a1b2
```

El sufijo se extrae del requestId (`REQ-accounta-68973-a1b2` → `a1b2`).

### Bloqueo de UI Durante Registro (2025-12-09)

**Mejora UX:** Deshabilitar el botón "Registrar en UAT" mientras hay un proceso en curso evita que usuarios impacientes creen solicitudes duplicadas.

```jsx
<Button
  disabled={inProgress}
  startIcon={inProgress ? <CircularProgress size={20} /> : <CloudUploadIcon />}
>
  Registrar en UAT
</Button>
```

### Permisos de Workflows Explícitos

**Bug resuelto:** `GITHUB_TOKEN` en `workflow_dispatch` no tiene permisos para crear Issues por defecto.

**Solución:** Declarar permisos explícitos:
```yaml
permissions:
  contents: read
  issues: write
  actions: write
```

### Path del ZIP Exportado por apictl

**Bug resuelto:** El comando `find -newer /tmp` no encontraba el ZIP exportado de forma confiable.

**Solución:** Usar el path exacto que apictl genera:
```bash
# El formato es: ~/.wso2apictl/exported/apis/{ENV}/{API}_{VERSION}.zip
ZIP_FILE="$HOME/.wso2apictl/exported/apis/wso2-docker/${API_NAME}_${API_VERSION}.zip"
```

### Workflows Rápidos y Race Conditions (2025-12-09)

**Bug resuelto:** Cuando el workflow se ejecuta muy rápido (ej: falla en 10 segundos por API no desplegada), el Publisher se quedaba en estado "validando" porque:
1. El workflow se dispara y termina antes de que el polling encuentre el run
2. Cuando el polling encuentra el run, ya está completado pero la lógica solo manejaba runs "in_progress"

**Solución:** Al encontrar un run, verificar si ya está completado y procesarlo inmediatamente:
```javascript
if (run.status === 'completed') {
    // Procesar resultado inmediatamente en lugar de esperar al siguiente poll
    if (run.conclusion === 'success') {
        pollHelixProcessor(triggeredAt, requestId);
    } else {
        const errorMsg = extractErrorFromJobs(jobsData);
        setRegistrationData({state: STATES.VALIDATION_FAILED, error: {...}});
    }
    return; // Exit polling
}
```

### Script de Build Sobrescribe Personalizaciones (2025-12-09)

**Bug resuelto:** `build-publisher.sh` copiaba `index.jsp` del build, perdiendo la línea de `apiops-config.js`.

**Solución:** Modificar el script para:
1. Si `index.jsp` existe, solo actualizar el hash del bundle con `sed`
2. Verificar que `apiops-config.js` está presente, si no, añadirlo
3. Solo crear nuevo `index.jsp` si no existe

### Dos Jobs vs Un Job (Confusión de Estados)

**Aclaración importante:** El flujo tiene DOS workflows secuenciales:
1. **WSO2-Processor** - Extrae API, valida subdominio configurado, valida deployment
2. **GIT-Helix-Processor** - Valida que subdominio existe, crea Issue, simula CRQ

Cuando el Publisher muestra "Job Succeeded" pero luego hay error, es porque:
- WSO2-Processor exitoso (subdominio configurado, API desplegada)
- GIT-Helix-Processor falla (subdominio no existe en repo-config.yaml)

Esto NO es un bug - es el comportamiento esperado. El mensaje de éxito es del primer workflow.

### Token para repository_dispatch (2025-12-09)

**Bug resuelto:** La simulación de aprobación de Helix fallaba con "Resource not accessible by integration" (HTTP 403).

**Causa:** El step usaba `GITHUB_TOKEN` pero `repository_dispatch` requiere un PAT con scope `repo`.

**Solución:**
1. Cambiar `GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}` por `GH_TOKEN: ${{ secrets.GIT_HELIX_PAT }}` en:
   - `process-api-request.yml` (steps: Create Issue, Create CRQ, Simulate Approval)
2. Añadir el secret `GIT_HELIX_PAT` en GIT-Helix-Processor (mismo valor que en WSO2-Processor)

### Auto-merge vs --auto flag (2025-12-09)

**Bug resuelto:** El workflow mostraba "Auto-merge not available" al intentar hacer merge de la PR.

**Causa:** El flag `--auto` de `gh pr merge` requiere que el repositorio tenga branch protection rules habilitadas. Sin ellas, el flag no funciona.

**Solución:** Usar merge directo sin `--auto`:
```bash
# Antes (requiere branch protection):
gh pr merge "${BRANCH_NAME}" --repo "${TARGET_REPO}" --auto --squash

# Ahora (funciona siempre):
gh pr merge "${BRANCH_NAME}" --repo "${TARGET_REPO}" --squash --delete-branch
```

**Justificación:** Helix ITSM ya realizó la aprobación humana. Una vez que Helix aprueba, no tiene sentido requerir otra revisión en GitHub. El merge inmediato es el comportamiento deseado.

### Polling en Dos Fases (2025-12-09)

**Problema:** El Publisher no detectaba cuando el flujo completo terminaba porque solo monitoreaba el primer workflow (`process-api-request.yml`), no el segundo (`on-helix-approval.yml`).

**Solución:** Implementar polling en dos fases en `UATRegistration.jsx`:

```javascript
// Fase 1: Esperar a que process-api-request.yml termine
// Buscar runs donde path incluye "process-api-request"
if (run.path?.includes('process-api-request') && run.status === 'completed') {
    if (run.conclusion === 'success') {
        phase = 2; // Pasar a fase 2
    }
}

// Fase 2: Esperar a que on-helix-approval.yml termine
// Buscar runs de tipo repository_dispatch
if (run.event === 'repository_dispatch' && run.status === 'completed') {
    if (run.conclusion === 'success') {
        setRegistrationData({state: STATES.REGISTERED, ...});
        MuiAlert.success('API registrada en UAT correctamente');
    }
}
```

**Resultado:** El Publisher ahora muestra el mensaje "API registrada correctamente" solo cuando todo el flujo ha terminado exitosamente (incluyendo el merge de la PR).
