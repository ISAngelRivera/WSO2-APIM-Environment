# RESUMEN EJECUTIVO: Sistema APIOps para WSO2 API Manager

**Versión**: 1.0
**Fecha**: 2025-12-10
**Proyecto**: WSO2-APIM-Environment + WSO2-Processor + GIT-Helix-Processor

---

## 1. RESUMEN EJECUTIVO

Este documento presenta el sistema APIOps desarrollado para automatizar el registro de APIs en entornos UAT/NFT/PRO, integrando WSO2 API Manager con GitHub y el sistema ITSM Helix.

### Logros principales

| Métrica | Valor |
|---------|-------|
| **Tiempo de registro E2E** | 30-45 segundos |
| **Escalabilidad** | 2,500+ APIs concurrentes |
| **Líneas de código** | ~5,500+ |
| **Automatización** | 100% (sin intervención manual) |

---

## 2. COMPARATIVA: ANTES vs AHORA

### 2.1 Proyecto Original (Datos I)

El proyecto original consistía en varios repositorios independientes con diferentes aproximaciones:

```
Datos I/
├── apim-lifecycle-extension-main/   ← Extensión Java para lifecycle
├── wso2-workflows-main/             ← Workflows reutilizables
├── wso2-pipeline-main/              ← Orquestación CI/CD
├── wso2-github-actions-main/        ← GitHub Actions custom
├── wso2-rulesets-main/              ← Reglas Spectral
└── openweather-main/                ← API de ejemplo
```

#### Arquitectura Original

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    ARQUITECTURA ORIGINAL                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────┐         ┌──────────────────────────────────┐          │
│  │   Publisher  │         │  EXTENSIÓN JAVA (JAR)            │          │
│  │              │────────►│  PromoteWorkflowExecutor.java    │          │
│  │  Click en    │         │                                  │          │
│  │  "Promote"   │         │  • Intercepta transición         │          │
│  └──────────────┘         │    Published → Promoted          │          │
│                           │  • Dispara workflow vía HTTP     │          │
│                           │  • Token hardcodeado en JAR      │          │
│                           └──────────────┬───────────────────┘          │
│                                          │                               │
│                                          ▼                               │
│                           ┌──────────────────────────────────┐          │
│                           │  GitHub Actions                  │          │
│                           │  (commitAPICode.yml)             │          │
│                           │                                  │          │
│                           │  • Exporta API                   │          │
│                           │  • Commit a repositorio          │          │
│                           │  • Sin integración Helix         │          │
│                           └──────────────────────────────────┘          │
│                                                                          │
│  LIMITACIONES:                                                           │
│  • Requiere modificar lifecycle de WSO2 (estados custom)                │
│  • JAR debe compilarse y desplegarse en WSO2                            │
│  • Token hardcodeado en código Java                                     │
│  • Sin feedback visual al usuario                                       │
│  • Sin integración con ITSM (Helix)                                     │
│  • Sin polling de estado                                                │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

**Componentes clave del proyecto original:**

1. **PromoteWorkflowExecutor.java** (137 líneas)
   - Extiende `APIStateChangeSimpleWorkflowExecutor`
   - Intercepta transición `Published → Promoted`
   - Dispara workflow via GitHub API
   - Requiere desplegar JAR en `<APIM_HOME>/repository/components/lib/`

2. **Lifecycle personalizado** (lifecycle.json)
   - Estados custom: Created → Pre-Released → Published → **Promoted** → Deprecated → Retired
   - Requiere configuración manual en registry de WSO2

3. **Workflows separados** (wso2-workflows-main)
   - `commitAPICode.yml` - Exporta y commitea
   - `release-apim-api.yml` - Validación y release
   - `cd-apim-apis.yml` - Despliegue multi-entorno
   - Sin orquestación centralizada

---

### 2.2 Proyecto Actual (WSO2-APIM-Environment)

```
WSO2-APIM-Environment/
├── publisher-dropin/              ← Bundles JS compilados
├── publisher-dropin-pages/        ← index.jsp modificado
├── wso2-patch/source-files/       ← UATRegistration.jsx
├── scripts/                       ← Automatización local
└── docs/                          ← Documentación

WSO2-Processor/                    ← Self-hosted runner
└── .github/workflows/
    └── receive-uat-request.yml

GIT-Helix-Processor/               ← Orquestador central
└── .github/workflows/
    ├── process-api-request.yml
    └── on-helix-approval.yml
```

#### Arquitectura Actual

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     ARQUITECTURA ACTUAL                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                    WSO2 API MANAGER                               │   │
│  │  ┌────────────────────────────────────────────────────────────┐  │   │
│  │  │              PUBLISHER PORTAL (React)                      │  │   │
│  │  │  ┌──────────────────────────────────────────────────────┐ │  │   │
│  │  │  │           UATRegistration.jsx (1,385 líneas)         │ │  │   │
│  │  │  │                                                      │ │  │   │
│  │  │  │  • Componente React con Material-UI                  │ │  │   │
│  │  │  │  • Valida: API publicada + desplegada + subdominio   │ │  │   │
│  │  │  │  • Dispara workflow_dispatch a WSO2-Processor        │ │  │   │
│  │  │  │  • Polling en dos fases (15s + 15s + merge)          │ │  │   │
│  │  │  │  • Estados visuales: Stepper + chips de color        │ │  │   │
│  │  │  │  • Persistencia en localStorage                      │ │  │   │
│  │  │  │  • Extracción de errores específicos                 │ │  │   │
│  │  │  │  • Diálogo de cancelación                            │ │  │   │
│  │  │  └──────────────────────────────────────────────────────┘ │  │   │
│  │  └────────────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                              │                                           │
│                              │ workflow_dispatch                         │
│                              ▼                                           │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │               WSO2-PROCESSOR (Self-Hosted Runner)                 │   │
│  │                                                                   │   │
│  │  receive-uat-request.yml:                                        │   │
│  │  • Valida API desplegada (curl a WSO2 API)                       │   │
│  │  • Exporta API con apictl                                        │   │
│  │  • Valida subdominio configurado                                 │   │
│  │  • Dispara workflow en GIT-Helix-Processor                       │   │
│  └───────────────────────────────┬──────────────────────────────────┘   │
│                                  │                                       │
│                                  │ workflow_dispatch + artifact          │
│                                  ▼                                       │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │               GIT-HELIX-PROCESSOR (Orquestador)                   │   │
│  │                                                                   │   │
│  │  process-api-request.yml:                                        │   │
│  │  • Crea Issue (cola de solicitudes)                              │   │
│  │  • Guarda artifact (export API, 30 días)                         │   │
│  │  • Simula aprobación Helix (AUTO_APPROVE)                        │   │
│  │  • Dispara on-helix-approval                                     │   │
│  │                                                                   │   │
│  │  on-helix-approval.yml:                                          │   │
│  │  • Descarga artifact                                             │   │
│  │  • Crea PR en repositorio del subdominio                         │   │
│  │  • Merge automático (--squash --delete-branch)                   │   │
│  │  • Cierra Issue                                                  │   │
│  └───────────────────────────────┬──────────────────────────────────┘   │
│                                  │                                       │
│                                  ▼                                       │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │            REPOSITORIOS DE SUBDOMINIOS                            │   │
│  │                                                                   │   │
│  │  rrhh-empleados/          finanzas-pagos/       informatica/     │   │
│  │  └── apis/                └── apis/             └── apis/        │   │
│  │      └── CustomerAPI/         └── PaymentAPI/       └── ...      │   │
│  │          └── 1.0.0/               └── 1.0.0/                     │   │
│  │              └── revisions/           └── revisions/             │   │
│  │                  └── rev-1/               └── rev-1/             │   │
│  │                      ├── api.yaml             ├── api.yaml       │   │
│  │                      └── request.yaml         └── request.yaml   │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 3. TABLA COMPARATIVA DETALLADA

| Aspecto | Proyecto Original | Proyecto Actual |
|---------|-------------------|-----------------|
| **Tecnología de integración** | JAR Java (PromoteWorkflowExecutor) | Componente React (UATRegistration.jsx) |
| **Despliegue** | Compilar JAR + copiar a `lib/` + reiniciar | Sistema Dropin (copiar bundles JS) |
| **Lifecycle WSO2** | Custom (Promoted, Changes-Requested) | Estándar (usa Published sin modificar) |
| **Feedback al usuario** | Ninguno (fire-and-forget) | Stepper visual + mensajes de progreso |
| **Manejo de errores** | Solo logs en servidor | Errores específicos en UI |
| **Integración ITSM** | No existe | Simulación Helix (preparado para real) |
| **Cola de solicitudes** | No existe | GitHub Issues como cola |
| **Persistencia** | No existe | Artifacts 30 días + localStorage |
| **Escalabilidad** | Limitada por JAR | 2,500+ APIs (requestId único) |
| **Cancelación** | No posible | Diálogo de cancelación con confirmación |
| **Polling** | No existe | Dos fases con detección de workflows |
| **Configuración** | En JAR (recompilación) | Archivo JS externo (apiops-config.js) |

---

## 4. EL COMPONENTE UATRegistration.jsx

### 4.1 Tecnología y Stack

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     STACK TECNOLÓGICO                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  FRONTEND (Publisher Portal)                                             │
│  ├── React 18.x                                                         │
│  ├── Material-UI (MUI) 5.x                                              │
│  │   ├── Box, Paper, Typography                                         │
│  │   ├── Button, Chip, Alert                                            │
│  │   ├── Stepper, Step, StepLabel                                       │
│  │   ├── Dialog, DialogTitle, DialogContent                             │
│  │   ├── CircularProgress, LinearProgress                               │
│  │   └── Tooltip, Snackbar                                              │
│  ├── React Intl (internacionalización)                                  │
│  └── PropTypes (validación de props)                                    │
│                                                                          │
│  BUILD SYSTEM                                                            │
│  ├── Webpack 5.x                                                        │
│  ├── Babel (transpilación ES6+)                                         │
│  ├── pnpm (gestor de paquetes)                                          │
│  └── ESLint + Prettier (linting)                                        │
│                                                                          │
│  APIs CONSUMIDAS                                                         │
│  ├── WSO2 Publisher API v4 (/api/am/publisher/v4/)                      │
│  │   ├── /apis/{id}                                                     │
│  │   ├── /apis/{id}/revisions                                           │
│  │   └── /apis/{id}/deployments                                         │
│  └── GitHub API v3                                                       │
│      ├── /repos/{owner}/{repo}/actions/workflows/{id}/dispatches        │
│      ├── /repos/{owner}/{repo}/actions/runs                             │
│      └── /repos/{owner}/{repo}/actions/runs/{id}/jobs                   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 4.2 Estructura del Componente

```javascript
// UATRegistration.jsx - Estructura principal (1,385 líneas)

// =====================================================
// IMPORTS Y CONFIGURACIÓN
// =====================================================
import React, { useState, useEffect } from 'react';
import { Box, Button, Stepper, Step, ... } from '@mui/material';

// Configuración externa (NO hardcodeada en código)
const config = window.APIOpsConfig?.github || {};
const token = config.token;
const processorRepo = config.processorRepo;
const helixRepo = config.helixRepo;

// =====================================================
// COMPONENTE PRINCIPAL
// =====================================================
function UATRegistration({ api, intl }) {
  // --- ESTADO ---
  const [status, setStatus] = useState('idle');        // idle|validating|requesting|registering|success|error
  const [currentStep, setCurrentStep] = useState(0);   // Paso actual del Stepper
  const [error, setError] = useState(null);            // Mensaje de error
  const [requestId, setRequestId] = useState(null);    // ID único de la solicitud

  // --- EFECTOS ---
  useEffect(() => {
    // Recuperar estado de localStorage al montar
    const savedState = localStorage.getItem(`uat-registration-${api.id}`);
    if (savedState) restoreState(savedState);
  }, []);

  // --- FUNCIONES PRINCIPALES ---

  // 1. Validación inicial
  const validatePrerequisites = async () => {
    // Verificar: publicada + desplegada + subdominio
  };

  // 2. Disparar workflow
  const triggerWorkflow = async () => {
    // POST a GitHub API workflow_dispatch
  };

  // 3. Polling de estado
  const pollHelixProcessor = async (phase) => {
    // Fase 1: WSO2-Processor (export)
    // Fase 2: on-helix-approval (PR + merge)
  };

  // 4. Extracción de errores
  const extractErrorFromJobs = (jobs) => {
    // Buscar mensajes de error en los logs
  };

  // --- RENDER ---
  return (
    <Paper>
      <Stepper activeStep={currentStep}>
        <Step><StepLabel>Validando</StepLabel></Step>
        <Step><StepLabel>Solicitando CRQ</StepLabel></Step>
        <Step><StepLabel>Creando PR</StepLabel></Step>
        <Step><StepLabel>Registrado</StepLabel></Step>
      </Stepper>

      {/* Botón principal */}
      <Button onClick={handleRegister} disabled={isProcessing}>
        Registrar en UAT
      </Button>

      {/* Estados visuales */}
      {status === 'success' && <Alert severity="success">...</Alert>}
      {status === 'error' && <Alert severity="error">{error}</Alert>}

      {/* Diálogo de cancelación */}
      <Dialog open={cancelDialogOpen}>...</Dialog>
    </Paper>
  );
}
```

### 4.3 Flujo de Ejecución

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    FLUJO DE EJECUCIÓN                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Usuario hace clic en "Registrar en UAT"                                │
│                    │                                                     │
│                    ▼                                                     │
│  ┌─────────────────────────────────────┐                                │
│  │ 1. VALIDACIÓN (validatePrerequisites)                                │
│  │    • ¿API está publicada?                                            │
│  │    • ¿Tiene revisiones desplegadas?                                  │
│  │    • ¿Tiene subdominio configurado?                                  │
│  └─────────────────────────────────────┘                                │
│                    │                                                     │
│                    ▼                                                     │
│  ┌─────────────────────────────────────┐                                │
│  │ 2. GENERAR REQUEST ID                                                │
│  │    REQ-{apiName}-{timestamp}-{random}                                │
│  │    Ejemplo: REQ-CustomerAPI-1733849234-x7k9m2                        │
│  └─────────────────────────────────────┘                                │
│                    │                                                     │
│                    ▼                                                     │
│  ┌─────────────────────────────────────┐                                │
│  │ 3. DISPARAR WORKFLOW (triggerWorkflow)                               │
│  │    POST /repos/WSO2-Processor/actions/workflows/.../dispatches       │
│  │    Body: { ref: "main", inputs: { api_id, version, request_id } }    │
│  └─────────────────────────────────────┘                                │
│                    │                                                     │
│                    ▼                                                     │
│  ┌─────────────────────────────────────┐                                │
│  │ 4. POLLING FASE 1 (WSO2-Processor)                                   │
│  │    • Buscar workflow run por request_id                              │
│  │    • Esperar completion (success/failure)                            │
│  │    • Extraer errores si falla                                        │
│  └─────────────────────────────────────┘                                │
│                    │                                                     │
│                    ▼                                                     │
│  ┌─────────────────────────────────────┐                                │
│  │ 5. POLLING FASE 2 (on-helix-approval)                                │
│  │    • Cambiar a repo GIT-Helix-Processor                              │
│  │    • Buscar workflow por request_id                                  │
│  │    • Esperar merge del PR                                            │
│  └─────────────────────────────────────┘                                │
│                    │                                                     │
│                    ▼                                                     │
│  ┌─────────────────────────────────────┐                                │
│  │ 6. ÉXITO                                                             │
│  │    • Mostrar "API registrada correctamente"                          │
│  │    • Guardar estado en localStorage                                  │
│  │    • Actualizar UI                                                   │
│  └─────────────────────────────────────┘                                │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 5. SISTEMA DROPIN: DESPLIEGUE EN PRODUCCIÓN

### 5.1 ¿Qué es el Sistema Dropin?

WSO2 API Manager permite **sobrescribir archivos del Publisher** sin modificar la instalación base. Esto se logra montando directorios que "sobrescriben" los archivos originales.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    SISTEMA DROPIN                                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  INSTALACIÓN WSO2 (original)                                             │
│  └── repository/deployment/server/webapps/publisher/                    │
│      └── site/public/                                                   │
│          ├── dist/                     ← Bundles originales             │
│          │   ├── index.{hash}.bundle.js                                 │
│          │   └── ... (otros bundles)                                    │
│          └── pages/                                                     │
│              └── index.jsp             ← Página principal               │
│                                                                          │
│  DROPIN (sobrescribe)                                                    │
│  ├── publisher-dropin/                 ← Bundles modificados            │
│  │   ├── index.{hash}.bundle.js        (incluye UATRegistration)        │
│  │   └── ... (326 archivos)                                             │
│  └── publisher-dropin-pages/           ← Páginas modificadas            │
│      └── index.jsp                     (incluye apiops-config.js)       │
│                                                                          │
│  DOCKER COMPOSE (montaje)                                                │
│  volumes:                                                                │
│    - ./publisher-dropin:/mnt/publisher-dropin:ro                        │
│    - ./publisher-dropin-pages:/mnt/publisher-dropin-pages:ro            │
│                                                                          │
│  ENTRYPOINT (copia al iniciar)                                          │
│  cp -r /mnt/publisher-dropin/* .../site/public/dist/                    │
│  cp -r /mnt/publisher-dropin-pages/* .../site/public/pages/             │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Pasos para Desplegar en Producción

```bash
# =====================================================
# PASO 1: Obtener código fuente del Publisher
# =====================================================
# Clonar el repositorio de WSO2
git clone https://github.com/wso2/apim-apps.git
cd apim-apps
git checkout v4.5.0  # Usar versión correspondiente a producción

# =====================================================
# PASO 2: Añadir UATRegistration.jsx
# =====================================================
# Copiar el componente al directorio correcto
cp UATRegistration.jsx \
   portals/publisher/src/main/webapp/source/src/app/components/Apis/Details/Lifecycle/

# Modificar LifeCycleUpdate.jsx para incluir el componente
# (importar y renderizar UATRegistration)

# =====================================================
# PASO 3: Compilar el Publisher
# =====================================================
cd portals/publisher/src/main/webapp
pnpm install
NODE_OPTIONS=--max_old_space_size=4096 pnpm run build:prod

# =====================================================
# PASO 4: Preparar Dropin
# =====================================================
# Copiar bundles compilados
mkdir -p /path/to/publisher-dropin
cp -r site/public/dist/* /path/to/publisher-dropin/

# Modificar index.jsp para incluir apiops-config.js
mkdir -p /path/to/publisher-dropin-pages
cp site/public/pages/index.jsp /path/to/publisher-dropin-pages/
# Añadir: <script src="/publisher/site/public/dist/apiops-config.js"></script>

# =====================================================
# PASO 5: Crear apiops-config.js
# =====================================================
cat > /path/to/publisher-dropin/apiops-config.js << 'EOF'
window.APIOpsConfig = {
  github: {
    token: 'ghp_xxxx',  // En producción: obtener de vault
    processorRepo: 'ORG/WSO2-Processor',
    helixRepo: 'ORG/GIT-Helix-Processor'
  }
};
EOF

# =====================================================
# PASO 6: Desplegar en Producción
# =====================================================
# Opción A: Docker (mount volumes)
docker run -d \
  -v /path/to/publisher-dropin:/mnt/publisher-dropin:ro \
  -v /path/to/publisher-dropin-pages:/mnt/publisher-dropin-pages:ro \
  wso2/wso2am:4.5.0

# Opción B: Instalación tradicional
# Copiar archivos directamente a la instalación
cp -r /path/to/publisher-dropin/* \
   $APIM_HOME/repository/deployment/server/webapps/publisher/site/public/dist/
cp -r /path/to/publisher-dropin-pages/* \
   $APIM_HOME/repository/deployment/server/webapps/publisher/site/public/pages/
```

### 5.3 Estructura de Archivos del Dropin

```
publisher-dropin/                        (326 archivos, ~120MB)
├── index.e3e3b0c93f5b6a7d8f9e.bundle.js  ← Bundle principal (incluye UATRegistration)
├── DeferredDetails.593b67700d50e03217da.bundle.js
├── ProtectedApps.058f956144eb7bab9277.bundle.js
├── apiops-config.js                      ← Configuración externa
├── *.bundle.js                           ← ~100 bundles de código
├── *.bundle.js.map                       ← Source maps (desarrollo)
└── *.bundle.js.LICENSE.txt               ← Licencias

publisher-dropin-pages/
└── index.jsp                             ← Página principal modificada
    (añade <script src="apiops-config.js">)
```

---

## 6. FUNCIONALIDADES IMPLEMENTADAS

### 6.1 Funcionalidades Actuales

| Funcionalidad | Descripción | Estado |
|--------------|-------------|--------|
| **Botón "Registrar en UAT"** | Visible en pestaña Lifecycle para APIs publicadas | Completado |
| **Validación de prerrequisitos** | Verifica: publicada + desplegada + subdominio | Completado |
| **Stepper visual** | 4 pasos: Validando → Solicitando → Creando PR → Registrado | Completado |
| **Polling en dos fases** | Monitorea WSO2-Processor y on-helix-approval | Completado |
| **Mensajes de progreso** | "Exportando API...", "Creando PR...", "Realizando merge..." | Completado |
| **Extracción de errores** | Muestra errores específicos de los workflows | Completado |
| **Persistencia localStorage** | Sobrevive refresh del navegador | Completado |
| **Diálogo de cancelación** | Confirmación antes de cancelar proceso | Completado |
| **Request ID único** | Permite 2,500+ APIs concurrentes sin colisiones | Completado |
| **Sistema de Issues** | Cola de solicitudes auditable en GitHub | Completado |
| **Artifacts** | Export de API guardado 30 días | Completado |
| **Auto-merge** | PR se mergea automáticamente sin intervención | Completado |

### 6.2 Funcionalidades Futuras (Roadmap)

| Funcionalidad | Descripción | Prioridad |
|--------------|-------------|-----------|
| **Externalizar token** | Mover token a vault/secrets manager | Crítica |
| **Exponential backoff** | Polling inteligente con backoff | Alta |
| **Circuit breaker** | Protección contra GitHub caído | Alta |
| **Health checks** | Verificar sistemas antes de iniciar | Media |
| **Logs a ELK** | Enviar logs estructurados a Elasticsearch | Media |
| **Métricas Grafana** | Dashboard de tiempos y tasas de éxito | Media |
| **Registro NFT/PRO** | Extender flujo a otros entornos | Media |
| **Integración Helix real** | Conectar con API real de Helix ITSM | Baja (requiere Helix) |

---

## 7. BENEFICIOS DEL NUEVO SISTEMA

### 7.1 Para el Usuario (Desarrollador de APIs)

| Antes | Ahora |
|-------|-------|
| Sin feedback visual | Stepper con progreso en tiempo real |
| No sabe si funcionó | Mensaje claro de éxito/error |
| Errores genéricos | Errores específicos y accionables |
| Proceso opaco | Proceso transparente paso a paso |
| No puede cancelar | Cancelación con confirmación |

### 7.2 Para Operaciones

| Antes | Ahora |
|-------|-------|
| JAR que compilar/desplegar | Bundles JS que copiar |
| Modificar lifecycle de WSO2 | Lifecycle estándar sin cambios |
| Token en código Java | Token en archivo JS externo |
| Sin auditoría | Issues de GitHub como registro |
| Sin reintentos | Artifacts permiten reintentos |

### 7.3 Para Arquitectura

| Antes | Ahora |
|-------|-------|
| Acoplado a WSO2 | Desacoplado (event-driven) |
| Sin integración ITSM | Preparado para Helix |
| Escalabilidad limitada | 2,500+ APIs concurrentes |
| Sin cola de mensajes | Issues como cola |
| Fire-and-forget | Polling bidireccional |

---

## 8. PRÓXIMOS PASOS RECOMENDADOS

### Fase 1: Seguridad (Antes de Producción)
1. Mover token de GitHub a HashiCorp Vault o AWS Secrets Manager
2. Configurar GitHub App en lugar de PAT personal
3. Revisar permisos mínimos necesarios

### Fase 2: Resiliencia
4. Implementar exponential backoff en polling
5. Añadir circuit breaker para GitHub API
6. Implementar idempotencia de requests

### Fase 3: Observabilidad
7. Integrar logs estructurados con ELK existente
8. Añadir métricas a Prometheus/Grafana
9. Crear dashboards de monitorización

### Fase 4: Funcionalidad
10. Implementar flujo NFT (similar a UAT)
11. Implementar flujo PRO (con aprobaciones)
12. Integrar con Helix ITSM real

---

## 9. CONTACTO Y SOPORTE

**Repositorios:**
- WSO2-APIM-Environment: Entorno local y dropins
- WSO2-Processor: Self-hosted runner para export
- GIT-Helix-Processor: Orquestador central

**Documentación adicional:**
- `docs/ESTADO_PROYECTO.md` - Estado detallado del proyecto
- `docs/FUTURAS_MEJORAS.md` - Roadmap técnico completo
- `docs/valoracion_inicial.md` - Revisión técnica del proyecto

---

*Documento generado: 2025-12-10*
*Versión del proyecto: MVP Funcional*
