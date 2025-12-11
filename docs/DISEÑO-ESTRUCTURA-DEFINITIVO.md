# Diseño Definitivo: Estructura de Repositorios Multi-Entorno

**Versión**: 1.0
**Fecha**: 2025-12-11
**Estado**: APROBADO

---

## 1. Estructura Final Confirmada

```
RRHH-Empleados/                              # Monorepo por DOMINIO
│
├── apis/
│   └── {APIName}/
│       ├── state.yaml                       # AUTO-GENERATED: Estado por entorno
│       │
│       └── {Version}/
│           └── {rev-N}/                     # Cada revisión es un snapshot inmutable
│               ├── api.yaml                 # Definición de la API
│               ├── Definitions/
│               │   └── swagger.yaml         # Contrato OpenAPI
│               └── Conf/
│                   ├── api_meta.yaml        # Metadata de deploy
│                   └── params.yaml          # Config de TODOS los entornos
│
├── repo-config.yaml                         # Configuración del dominio
└── README.md
```

### Ejemplo Real

```
RRHH-Empleados/
├── apis/
│   ├── AttendanceAPI/
│   │   ├── state.yaml
│   │   ├── v1.0.0/
│   │   │   ├── rev-1/
│   │   │   │   ├── api.yaml
│   │   │   │   ├── Definitions/
│   │   │   │   │   └── swagger.yaml
│   │   │   │   └── Conf/
│   │   │   │       ├── api_meta.yaml
│   │   │   │       └── params.yaml
│   │   │   │
│   │   │   └── rev-2/
│   │   │       ├── api.yaml
│   │   │       ├── Definitions/
│   │   │       │   └── swagger.yaml
│   │   │       └── Conf/
│   │   │           ├── api_meta.yaml
│   │   │           └── params.yaml
│   │   │
│   │   └── v2.0.0/
│   │       └── rev-1/
│   │           └── ...
│   │
│   └── PayrollAPI/
│       ├── state.yaml
│       └── v1.0.0/
│           └── rev-1/
│               └── ...
│
├── repo-config.yaml
└── README.md
```

---

## 2. Principios de Diseño

### 2.1 Cada revisión es un SNAPSHOT INMUTABLE

Una revisión contiene TODO lo necesario para desplegar:
- `api.yaml` - Definición de la API
- `swagger.yaml` - Contrato OpenAPI
- `params.yaml` - Configuración de TODOS los entornos

**¿Por qué?** Si me piden "despliega rev-2 de AttendanceAPI v1.0.0 en NFT", tengo todo en una carpeta.

### 2.2 params.yaml contiene TODOS los entornos

Un solo archivo con las secciones UAT, NFT, PRO:
- Formato nativo de WSO2 apictl
- Sin transformaciones en CI/CD
- Estándar de industria (wso2-cicd)

### 2.3 Trazabilidad 100%

Cada cambio (endpoint, policy, certificado) genera nueva revisión:
- Git history muestra qué cambió
- `state.yaml` muestra qué revisión está en cada entorno
- CRQ de Helix vinculado a cada deploy

---

## 3. Archivos Detallados

### 3.1 `api.yaml` (Definición - ESTÁTICO por revisión)

```yaml
type: api
version: v4.5.0
data:
  name: AttendanceAPI
  context: /attendance
  version: 1.0.0
  provider: admin
  lifeCycleStatus: PUBLISHED
  type: HTTP
  transport:
    - http
    - https
  tags: []
  securityScheme:
    - oauth2
  visibility: PUBLIC
  visibleRoles: []
  accessControl: NONE
  corsConfiguration:
    corsConfigurationEnabled: false
    accessControlAllowOrigins:
      - '*'
    accessControlAllowCredentials: false
    accessControlAllowHeaders:
      - authorization
      - Content-Type
      - apikey
    accessControlAllowMethods:
      - GET
      - PUT
      - POST
      - DELETE
      - PATCH
      - OPTIONS
  operations:
    - target: "/employees"
      verb: GET
      authType: Application & Application User
      throttlingPolicy: Unlimited
    - target: "/employees/{id}"
      verb: GET
      authType: Application & Application User
      throttlingPolicy: Unlimited
  # Metadata custom
  additionalProperties:
    - name: subdominio
      value: rrhh-empleados
      display: true
    - name: API_TYPE
      value: SYSTEM
      display: false
```

### 3.2 `Definitions/swagger.yaml` (Contrato - ESTÁTICO por revisión)

```yaml
openapi: 3.0.1
info:
  title: AttendanceAPI
  description: API para gestión de asistencia de empleados
  version: 1.0.0
  contact:
    name: Equipo RRHH
    email: team-rrhh@company.com

servers:
  - url: /

paths:
  /employees:
    get:
      summary: Listar empleados
      description: Obtiene la lista de todos los empleados
      operationId: getEmployees
      parameters:
        - name: X-Correlation-ID
          in: header
          required: false
          schema:
            type: string
      responses:
        '200':
          description: Lista de empleados
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/Employee'
        '401':
          description: No autorizado
        '500':
          description: Error interno

  /employees/{id}:
    get:
      summary: Obtener empleado por ID
      operationId: getEmployeeById
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Empleado encontrado
        '404':
          description: Empleado no encontrado

components:
  schemas:
    Employee:
      type: object
      properties:
        id:
          type: string
        name:
          type: string
        department:
          type: string

  securitySchemes:
    default:
      type: oauth2
      flows:
        implicit:
          authorizationUrl: https://localhost:9443/oauth2/authorize
          scopes: {}

security:
  - default: []

x-wso2-auth-header: Authorization
x-wso2-api-key-header: ApiKey
x-wso2-basePath: /attendance/1.0.0
x-wso2-transports:
  - http
  - https
```

### 3.3 `Conf/api_meta.yaml` (Metadata de deploy)

```yaml
deploy:
  import:
    preserveProvider: false      # Usar provider del entorno destino
    rotateRevision: true         # Crear nueva revisión en WSO2
    update: true                 # Actualizar si ya existe
name: AttendanceAPI
version: 1.0.0
```

### 3.4 `Conf/params.yaml` (Configuración por entorno - DINÁMICO)

```yaml
# =============================================================================
# AttendanceAPI v1.0.0 rev-1 - Configuración por Entorno
# =============================================================================
# Este archivo define la configuración específica de cada entorno.
# Cada revisión tiene su propio params.yaml (snapshot inmutable).
#
# Formato: WSO2 apictl params.yaml nativo
# Docs: https://apim.docs.wso2.com/en/latest/install-and-setup/setup/api-controller/advanced-topics/configuring-environment-specific-parameters/
# =============================================================================

environments:
  # ---------------------------------------------------------------------------
  # UAT - Desarrollo/Testing
  # ---------------------------------------------------------------------------
  - name: uat
    configs:
      # Endpoints del backend
      endpoints:
        production:
          url: https://api-uat.internal.company.com/rrhh/attendance/v1
          config:
            retryTimeOut: 2                    # Reintentos antes de suspender
            retryDelay: 500                    # Delay entre reintentos (ms)
            retryErroCode:
              - "101503"                       # Connection Timeout
              - "101504"                       # Connection Closed
            suspendDuration: 10000             # Suspensión inicial (ms)
            suspendMaxDuration: 30000          # Suspensión máxima (ms)
            suspendErrorCode:
              - "101501"                       # Connection Failed
              - "101504"
            actionSelect: fault                # fault | discard
            actionDuration: 30000
        sandbox:
          url: https://sandbox-uat.internal.company.com/rrhh/attendance/v1

      # Seguridad del endpoint (backend)
      security:
        production:
          enabled: true
          type: basic
          username: ${UAT_BACKEND_USER}
          password: ${UAT_BACKEND_PASS}
        sandbox:
          enabled: false

      # Certificados backend (para HTTPS)
      certs: []

      # Certificados mTLS (para clientes)
      mutualSslCerts: []

      # Políticas de throttling
      policies:
        - Gold

      # Gateways de deployment
      deploymentEnvironments:
        - displayOnDevportal: true
          deploymentEnvironment: UAT-Gateway

  # ---------------------------------------------------------------------------
  # NFT - Pre-producción / QA
  # ---------------------------------------------------------------------------
  - name: nft
    configs:
      endpoints:
        production:
          url: https://api-nft.internal.company.com/rrhh/attendance/v1
          config:
            retryTimeOut: 3
            retryDelay: 1000
            retryErroCode:
              - "101503"
              - "101504"
            suspendDuration: 30000
            suspendMaxDuration: 60000
            suspendErrorCode:
              - "101501"
              - "101504"
            factor: 2                          # Backoff exponencial
            actionSelect: fault
            actionDuration: 60000

      security:
        production:
          enabled: true
          type: oauth2
          tokenUrl: https://idp-nft.company.com/oauth2/token
          clientId: ${NFT_CLIENT_ID}
          clientSecret: ${NFT_CLIENT_SECRET}
          grantType: client_credentials

      certs:
        - hostName: https://api-nft.internal.company.com
          alias: nft-backend-cert
          path: certs/nft-backend.pem

      mutualSslCerts: []

      policies:
        - Platinum

      deploymentEnvironments:
        - displayOnDevportal: true
          deploymentEnvironment: NFT-Gateway

  # ---------------------------------------------------------------------------
  # PRO - Producción
  # ---------------------------------------------------------------------------
  - name: pro
    configs:
      endpoints:
        production:
          url: https://api.company.com/rrhh/attendance/v1
          config:
            retryTimeOut: 5
            retryDelay: 2000
            retryErroCode:
              - "101503"
              - "101504"
              - "101505"
            suspendDuration: 60000
            suspendMaxDuration: 300000
            suspendErrorCode:
              - "101501"
              - "101504"
            factor: 3
            actionSelect: fault
            actionDuration: 120000

      security:
        production:
          enabled: true
          type: oauth2
          tokenUrl: https://idp.company.com/oauth2/token
          clientId: ${PRO_CLIENT_ID}
          clientSecret: ${PRO_CLIENT_SECRET}
          grantType: client_credentials

      certs:
        - hostName: https://api.company.com
          alias: pro-backend-cert
          path: certs/pro-backend.pem

      mutualSslCerts:
        - tierName: Unlimited
          alias: pro-mtls-client
          path: certs/pro-mtls.crt

      policies:
        - Platinum
        - Diamond
        - Unlimited

      deploymentEnvironments:
        - displayOnDevportal: true
          deploymentEnvironment: Production-Gateway
          deploymentVhost: api.company.com
```

### 3.5 `state.yaml` (Estado - AUTO-GENERATED)

```yaml
# =============================================================================
# AttendanceAPI - Estado de Deployments por Entorno
# =============================================================================
# ARCHIVO AUTO-GENERADO por GIT-Helix-Processor
# NO EDITAR MANUALMENTE
#
# Última actualización: 2025-12-11T14:30:00Z
# =============================================================================

api_name: AttendanceAPI
last_updated: 2025-12-11T14:30:00Z

# Estado actual en cada entorno
environments:
  uat:
    version: 1.0.0
    revision: rev-2
    status: DEPLOYED
    deployed_at: 2025-12-11T10:00:00Z
    deployed_by: dev1@carbon.super
    helix_crq: CRQ-20251211100000
    workflow_url: https://github.com/.../actions/runs/12345

  nft:
    version: 1.0.0
    revision: rev-1
    status: DEPLOYED
    deployed_at: 2025-12-10T15:30:00Z
    deployed_by: qa@carbon.super
    helix_crq: CRQ-20251210153000
    workflow_url: https://github.com/.../actions/runs/12340
    promoted_from:
      environment: uat
      revision: rev-1
      crq: CRQ-20251210100000

  pro:
    version: 1.0.0
    revision: rev-1
    status: DEPLOYED
    deployed_at: 2025-12-01T09:00:00Z
    deployed_by: release-manager@carbon.super
    helix_crq: CRQ-20251201090000
    workflow_url: https://github.com/.../actions/runs/12300
    promoted_from:
      environment: nft
      revision: rev-1
      crq: CRQ-20251130150000

# Historial de operaciones
history:
  - timestamp: 2025-12-11T10:00:00Z
    action: DEPLOY
    environment: uat
    version: 1.0.0
    revision: rev-2
    crq: CRQ-20251211100000
    user: dev1@carbon.super
    changes:
      - "Updated production endpoint URL"

  - timestamp: 2025-12-10T15:30:00Z
    action: PROMOTE
    from_environment: uat
    to_environment: nft
    version: 1.0.0
    revision: rev-1
    crq: CRQ-20251210153000
    user: qa@carbon.super

  - timestamp: 2025-12-01T09:00:00Z
    action: PROMOTE
    from_environment: nft
    to_environment: pro
    version: 1.0.0
    revision: rev-1
    crq: CRQ-20251201090000
    user: release-manager@carbon.super
```

---

## 4. Flujos de Trabajo

### 4.1 DEPLOY en UAT (Nueva API o Nueva Revisión)

```
┌─────────────────────────────────────────────────────────────────────┐
│ 1. Usuario crea/modifica API en WSO2 Publisher (UAT)                │
│ 2. Usuario crea revisión y despliega                                │
│ 3. Usuario hace clic en "Registrar en UAT"                          │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│ WSO2-Processor                                                       │
│ - Detecta evento                                                     │
│ - Exporta API completa (apictl export)                              │
│ - Envía a GIT-Helix-Processor                                       │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│ GIT-Helix-Processor                                                  │
│ - Valida subdominio                                                  │
│ - Crea Issue "UAT DEPLOY: AttendanceAPI v1.0.0 rev-2"               │
│ - Guarda artifact                                                    │
│ - Crea CRQ en Helix ITSM                                            │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│ Helix ITSM                                                           │
│ - Aprueba CRQ (o rechaza)                                           │
│ - Envía webhook a GIT-Helix-Processor                               │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│ on-helix-approval.yml                                                │
│ - Descarga artifact                                                  │
│ - Crea estructura: apis/AttendanceAPI/v1.0.0/rev-2/                 │
│ - Copia api.yaml, swagger.yaml                                      │
│ - Genera params.yaml inicial (o copia de rev anterior)              │
│ - Actualiza state.yaml                                              │
│ - Crea PR y auto-merge                                              │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.2 PROMOTE (UAT → NFT → PRO)

```
┌─────────────────────────────────────────────────────────────────────┐
│ 1. Admin ejecuta workflow "Promote API"                             │
│    - apiName: AttendanceAPI                                          │
│    - version: 1.0.0                                                  │
│    - revision: rev-1                                                 │
│    - sourceEnv: uat                                                  │
│    - targetEnv: nft                                                  │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│ promote-api.yml                                                      │
│ - Valida que rev-1 existe en apis/.../v1.0.0/rev-1/                 │
│ - Valida que params.yaml tiene sección "nft"                        │
│ - Crea Issue "NFT PROMOTE: AttendanceAPI v1.0.0 rev-1"              │
│ - Crea CRQ en Helix (mayor scrutiny para NFT/PRO)                   │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│ Helix ITSM                                                           │
│ - Revisión más estricta (QA sign-off, CAB para PRO)                 │
│ - Aprueba CRQ                                                        │
│ - Envía webhook                                                      │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│ on-helix-approval.yml (action=promote)                              │
│ - Lee apis/AttendanceAPI/v1.0.0/rev-1/                              │
│ - NO copia archivos (ya existen)                                     │
│ - Actualiza state.yaml → nft: rev-1                                 │
│ - Añade entry en history                                             │
│ - Crea PR y auto-merge                                              │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│ CI/CD Pipeline (FUTURO)                                              │
│ - Detecta cambio en state.yaml                                       │
│ - Lee revisión indicada                                              │
│ - Ejecuta: apictl import api -f rev-1/ -e nft --params params.yaml  │
│ - Despliega en WSO2 NFT                                             │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.3 ROLLBACK

```
┌─────────────────────────────────────────────────────────────────────┐
│ 1. Incidente en PRO con rev-2                                        │
│ 2. Admin ejecuta workflow "Rollback API"                            │
│    - apiName: AttendanceAPI                                          │
│    - version: 1.0.0                                                  │
│    - targetRevision: rev-1  (volver a rev-1)                        │
│    - environment: pro                                                │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│ rollback-api.yml                                                     │
│ - Valida que rev-1 existe                                            │
│ - Crea Issue "PRO ROLLBACK: AttendanceAPI v1.0.0 rev-2 → rev-1"    │
│ - Crea CRQ EMERGENCY en Helix                                       │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│ Tras aprobación:                                                     │
│ - Actualiza state.yaml → pro: rev-1                                 │
│ - Añade entry en history (action: ROLLBACK)                         │
│ - CI/CD despliega rev-1 en PRO                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 5. Sistema de Issues

### 5.1 Labels

| Label | Color | Descripción |
|-------|-------|-------------|
| `env:uat` | `#1d76db` | Target: UAT |
| `env:nft` | `#fbca04` | Target: NFT |
| `env:pro` | `#d73a4a` | Target: PRO |
| `action:deploy` | `#0e8a16` | Nuevo deploy |
| `action:promote` | `#a2eeef` | Promoción entre entornos |
| `action:rollback` | `#e99695` | Rollback a revisión anterior |
| `status:pending-helix` | `#fbca04` | Esperando Helix |
| `status:approved` | `#0e8a16` | Aprobado |
| `status:rejected` | `#d73a4a` | Rechazado |

### 5.2 Formato de Títulos

```
{ENV} {ACTION}: {APIName} v{Version} rev-{N} [{REQUEST_ID}]
```

Ejemplos:
- `UAT DEPLOY: AttendanceAPI v1.0.0 rev-1 [REQ-xxx]`
- `NFT PROMOTE: AttendanceAPI v1.0.0 rev-1 [REQ-yyy]`
- `PRO ROLLBACK: AttendanceAPI v1.0.0 rev-2 → rev-1 [REQ-zzz]`

---

## 6. Métricas de Escala

| Escenario | Archivos |
|-----------|----------|
| 2,500 APIs × 2 versiones × 4 revisiones promedio | ~20,000 carpetas de revisión |
| Cada revisión: 4 archivos (api.yaml, swagger.yaml, api_meta.yaml, params.yaml) | ~80,000 archivos |
| + 2,500 state.yaml (uno por API) | +2,500 archivos |
| **Total estimado** | **~82,500 archivos** |

Distribuidos en ~10 repos de dominio = ~8,250 archivos por repo.

---

## 7. Conexión con Backend Service (Futuro)

Añadir metadata custom en `api.yaml`:

```yaml
additionalProperties:
  - name: subdominio
    value: rrhh-empleados
    display: true
  - name: backend_service
    value: attendance-service
    display: false
  - name: backend_repo
    value: https://github.com/company/attendance-service
    display: false
  - name: team
    value: rrhh-core
    display: false
  - name: contact
    value: rrhh-core@company.com
    display: false
```

---

## 8. Checklist de Implementación

### Fase 1: Estructura
- [ ] Actualizar template de repos de dominio
- [ ] Crear script de migración desde estructura actual
- [ ] Migrar RRHH-Empleados
- [ ] Migrar Finanzas-Pagos

### Fase 2: Workflows
- [ ] Actualizar `process-api-request.yml` para nueva estructura
- [ ] Actualizar `on-helix-approval.yml` para crear revisiones
- [ ] Crear `promote-api.yml`
- [ ] Crear `rollback-api.yml`

### Fase 3: Labels
- [ ] Crear labels `env:*`
- [ ] Crear labels `action:*`
- [ ] Actualizar formato de Issues

### Fase 4: Testing
- [ ] E2E: Deploy nueva API en UAT
- [ ] E2E: Crear nueva revisión en UAT
- [ ] E2E: Promote UAT → NFT
- [ ] E2E: Promote NFT → PRO
- [ ] E2E: Rollback en PRO

### Fase 5: Documentación
- [ ] Guía de estructura para desarrolladores
- [ ] Guía de promoción entre entornos
- [ ] Runbook de rollback

---

## 9. Referencias

- [wso2-cicd Organization](https://github.com/wso2-cicd)
- [WSO2 apictl Environment Parameters](https://apim.docs.wso2.com/en/latest/install-and-setup/setup/api-controller/advanced-topics/configuring-environment-specific-parameters/)
- [Flux Repository Structure](https://fluxcd.io/flux/guides/repository-structure/)
- [Rajkumar Rajaratnam - CI/CD for WSO2](https://medium.com/@rajkumar.rajaratnam/ci-cd-for-wso2-products-part-1-deploying-apis-to-wso2-api-manager-using-api-controller-b64fa90b4472)
