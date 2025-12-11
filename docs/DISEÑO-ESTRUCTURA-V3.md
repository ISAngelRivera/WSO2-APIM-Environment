# Diseño Definitivo: Estructura Multi-Entorno v3 (Sin Revisiones)

**Versión**: 3.0
**Fecha**: 2025-12-11
**Estado**: APROBADO E IMPLEMENTADO

---

## 1. Estructura Final Simplificada

```
RRHH-Empleados/                              # Monorepo por DOMINIO
│
├── apis/
│   └── {APIName}/
│       ├── state.yaml                       # AUTO-GENERATED: Estado por entorno
│       │
│       └── {Version}/                       # Sin revisiones - se actualiza directamente
│           ├── api.yaml                     # Definición de la API
│           ├── Definitions/
│           │   └── swagger.yaml             # Contrato OpenAPI
│           └── Conf/
│               ├── api_meta.yaml            # Metadata de deploy
│               ├── params.yaml              # Config de TODOS los entornos
│               └── request.yaml             # Última solicitud (trazabilidad)
│
└── README.md
```

### Ejemplo Real

```
RRHH-Empleados/
├── apis/
│   ├── AttendanceAPI/
│   │   ├── state.yaml
│   │   ├── 1.0.0/
│   │   │   ├── api.yaml
│   │   │   ├── Definitions/
│   │   │   │   └── swagger.yaml
│   │   │   └── Conf/
│   │   │       ├── api_meta.yaml
│   │   │       ├── params.yaml
│   │   │       └── request.yaml
│   │   │
│   │   └── 2.0.0/
│   │       ├── api.yaml
│   │       ├── Definitions/
│   │       │   └── swagger.yaml
│   │       └── Conf/
│   │           ├── api_meta.yaml
│   │           ├── params.yaml
│   │           └── request.yaml
│   │
│   └── PayrollAPI/
│       ├── state.yaml
│       └── 1.0.0/
│           └── ...
│
└── README.md
```

---

## 2. Principios de Diseño v3

### 2.1 Cada registro SOBRESCRIBE la versión

- **Sin revisiones** - WSO2 mantiene sus revisiones internas (max 4)
- **Cada "Registrar en UAT"** actualiza los archivos de la versión
- **Simplicidad** - ~5000 archivos vs ~15000 con revisiones (para 2500 APIs)

### 2.2 Comportamiento del registro

```
Usuario hace clic en "Registrar en UAT"
         │
         ▼
┌─────────────────────────────────────┐
│  ¿Existe apis/{API}/{Version}/ ?   │
├─────────────────────────────────────┤
│  NO  → Crear carpeta + archivos    │
│  SÍ  → Sobrescribir (actualizar)   │
└─────────────────────────────────────┘
```

### 2.3 params.yaml contiene TODOS los entornos

Un solo archivo con las secciones UAT, NFT, PRO:
- Formato nativo de WSO2 apictl
- Sin transformaciones en CI/CD
- Estándar de industria (wso2-cicd)

### 2.4 Trazabilidad

- `request.yaml` guarda la ÚLTIMA solicitud (quién, cuándo, CRQ)
- Git history muestra todos los cambios
- `state.yaml` muestra qué versión está en cada entorno

---

## 3. Archivos Detallados

### 3.1 `api.yaml` (Definición - se actualiza)

```yaml
# Exportado desde WSO2 APIM
# Se sobrescribe en cada registro
type: api
version: v4.3.0
data:
  name: AttendanceAPI
  description: "API para gestión de asistencia"
  context: /attendance
  version: 1.0.0
  provider: admin
  lifeCycleStatus: PUBLISHED
  # ... más campos de WSO2
```

### 3.2 `params.yaml` (Configuración Multi-Entorno)

```yaml
# =============================================================================
# AttendanceAPI 1.0.0 - Configuración por Entorno
# =============================================================================
# Última actualización: 2025-12-11T14:00:00Z
# CRQ: CRQ-12345
# =============================================================================

environments:
  # ---------------------------------------------------------------------------
  # UAT - Desarrollo/Testing
  # ---------------------------------------------------------------------------
  - name: uat
    configs:
      endpoints:
        production:
          url: https://backend-uat.internal/attendance
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
          url: https://backend-nft.internal/attendance
          config:
            retryTimeOut: 3
            retryDelay: 1000
            suspendDuration: 30000
            suspendMaxDuration: 60000

      policies:
        - Platinum

      # ... resto de config

  # ---------------------------------------------------------------------------
  # PRO - Producción
  # ---------------------------------------------------------------------------
  - name: pro
    configs:
      endpoints:
        production:
          url: https://api.company.com/attendance
          config:
            retryTimeOut: 5
            retryDelay: 2000
            suspendDuration: 60000
            suspendMaxDuration: 300000

      policies:
        - Unlimited

      # ... resto de config
```

### 3.3 `state.yaml` (Estado por Entorno)

```yaml
# =============================================================================
# AttendanceAPI - Estado de Deployments por Entorno
# =============================================================================
# ARCHIVO AUTO-GENERADO por GIT-Helix-Processor
# Se actualiza en cada registro
# =============================================================================

api_name: AttendanceAPI
last_updated: 2025-12-11T14:00:00Z

environments:
  uat:
    version: "1.0.0"
    status: REGISTERED
    registered_at: 2025-12-11T14:00:00Z
    registered_by: dev1
    helix_crq: CRQ-12345

  nft:
    version: null
    status: NOT_DEPLOYED

  pro:
    version: null
    status: NOT_DEPLOYED

last_registration:
  request_id: REQ-attendance-12345-abc1
  timestamp: 2025-12-11T14:00:00Z
  api_version: "1.0.0"
  crq: CRQ-12345
  user: dev1
```

### 3.4 `request.yaml` (Trazabilidad última solicitud)

```yaml
# =============================================================================
# Última solicitud de registro
# =============================================================================
# Este archivo se sobrescribe en cada registro
# =============================================================================

request_id: REQ-attendance-12345-abc1
timestamp: 2025-12-11T14:00:00Z
action: deploy
environment: uat
subdominio: rrhh-empleados

helix:
  crq_id: CRQ-12345
  status: APPROVED

api:
  name: AttendanceAPI
  version: 1.0.0

user: dev1
approval_workflow: https://github.com/org/repo/actions/runs/12345
```

---

## 4. Comparativa v2 vs v3

| Aspecto | v2 (Con Revisiones) | v3 (Sin Revisiones) |
|---------|---------------------|---------------------|
| Estructura | `{Ver}/{rev-N}/` | `{Ver}/` |
| Archivos (2500 APIs) | ~15000 | ~5000 |
| Trazabilidad | 100% (cada revisión) | Parcial (última solicitud) |
| Rollback | Fácil (carpeta anterior) | Re-exportar de WSO2 |
| Complejidad | Mayor | **Menor** |
| Estándar Hard Rock | No compatible | **Compatible** |

---

## 5. Flujo de Registro

```
1. Usuario hace clic en "Registrar en UAT"
2. WSO2-Processor exporta API
3. GIT-Helix-Processor crea Issue + simula CRQ
4. on-helix-approval:
   a. Clona repo del dominio
   b. ¿Existe apis/{API}/{Ver}/?
      - NO → mkdir -p
      - SÍ → (se sobrescribirá)
   c. Copia api.yaml, swagger.yaml
   d. Genera params.yaml con 3 entornos
   e. Genera request.yaml (trazabilidad)
   f. Actualiza state.yaml
   g. Commit + Push + PR + Auto-merge
5. Publisher muestra "API registrada correctamente"
```

---

## 6. Flujo de Promoción

```
promote-api.yml (UAT → NFT → PRO)

1. Valida flujo: uat→nft o nft→pro
2. Verifica versión existe en repo
3. Verifica estado en origen (REGISTERED o DEPLOYED)
4. Actualiza state.yaml con nuevo entorno
5. Commit + Push

TODO: Integrar con apictl para deploy real a WSO2 de cada entorno
```

---

## 7. Decisión de Eliminar Revisiones

### Razones:

1. **Simplicidad**: 2500 APIs × 2 versiones = 5000 carpetas vs 15000
2. **Estándar**: wso2-cicd (Hard Rock) no usa revisiones
3. **WSO2**: Las revisiones son internas de WSO2, no necesitamos replicarlas
4. **Rollback real**: En producción se hace a nivel de versión, no de revisión
5. **Mantenimiento**: Menos código, menos errores

### Qué se pierde:

- Histórico detallado de cada registro (se mantiene en Git history)
- Capacidad de desplegar revisión específica (se usa la última siempre)

### Compensaciones:

- `request.yaml` guarda quién/cuándo/CRQ de la última solicitud
- Git history mantiene todo el histórico
- `state.yaml` muestra estado actual por entorno
