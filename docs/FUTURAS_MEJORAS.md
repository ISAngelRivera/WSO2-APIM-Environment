# Futuras Mejoras - WSO2 APIOps Environment

Documento para registrar mejoras técnicas identificadas en la revisión del proyecto y ideas de evolución futura.

---

## PARTE 1: MEJORAS TÉCNICAS PRIORIZADAS

Mejoras identificadas en la revisión técnica para llevar el proyecto de 7.5/10 a 10/10.

---

### 1. ARQUITECTURA Y RESILIENCIA (Prioridad: ALTA)

#### 1.1 Retry con Exponential Backoff
- **Estado actual**: Polling con intervalos fijos (3 segundos)
- **Problema**: Sobrecarga innecesaria a GitHub API, no respeta rate limits
- **Solución**: Implementar backoff exponencial con jitter

```javascript
// En UATRegistration.jsx - Reemplazar pollInterval fijo
const calculateBackoff = (attempt, baseDelay = 3000, maxDelay = 30000) => {
  const exponentialDelay = baseDelay * Math.pow(2, attempt);
  const jitter = Math.random() * 1000; // Evita thundering herd
  return Math.min(exponentialDelay + jitter, maxDelay);
};

// Uso en pollHelixProcessor
const poll = async (attempt = 0) => {
  try {
    const result = await checkWorkflowStatus();
    if (result.status === 'pending') {
      const delay = calculateBackoff(attempt);
      console.log(`Retry en ${delay}ms (intento ${attempt + 1})`);
      setTimeout(() => poll(attempt + 1), delay);
    }
  } catch (error) {
    if (error.status === 429) { // Rate limited
      const retryAfter = error.headers['retry-after'] || 60;
      setTimeout(() => poll(attempt), retryAfter * 1000);
    }
  }
};
```

- **Impacto**: Alto (Resiliencia)
- **Esfuerzo**: Bajo
- **Archivos**: `UATRegistration.jsx`

---

#### 1.2 Dead Letter Queue (DLQ)
- **Estado actual**: Issues fallidos quedan con label `failed` pero sin reprocesamiento
- **Problema**: No hay mecanismo automático de recuperación
- **Solución**: Implementar DLQ con workflow de limpieza

```yaml
# .github/workflows/process-dlq.yml (GIT-Helix-Processor)
name: Process Dead Letter Queue
on:
  schedule:
    - cron: '0 */6 * * *'  # Cada 6 horas
  workflow_dispatch:

jobs:
  process-dlq:
    runs-on: ubuntu-latest
    steps:
      - name: Find failed issues older than 1 hour
        id: find
        run: |
          ISSUES=$(gh issue list \
            --label "failed" \
            --json number,createdAt,title \
            --jq '.[] | select(
              (now - (.createdAt | fromdateiso8601)) > 3600
            )')
          echo "issues=$ISSUES" >> $GITHUB_OUTPUT
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Retry or escalate
        run: |
          for issue in ${{ steps.find.outputs.issues }}; do
            RETRY_COUNT=$(gh issue view $issue --json body \
              --jq '.body | capture("retry_count: (?<n>[0-9]+)") | .n // "0"')

            if [ "$RETRY_COUNT" -lt 3 ]; then
              # Reintentar
              gh issue edit $issue --remove-label "failed" --add-label "retry-pending"
              gh workflow run process-api-request.yml -f issue_number=$issue
            else
              # Escalar - requiere intervención manual
              gh issue edit $issue --add-label "needs-manual-review"
              # Notificar a Slack/Teams
            fi
          done
```

- **Impacto**: Alto (Recuperación automática)
- **Esfuerzo**: Medio
- **Archivos**: Nuevo workflow en GIT-Helix-Processor

---

#### 1.3 Circuit Breaker Pattern
- **Estado actual**: Si GitHub está caído, se siguen haciendo requests
- **Problema**: Desperdicio de recursos, mala UX
- **Solución**: Implementar circuit breaker

```javascript
// lib/CircuitBreaker.js (nuevo archivo)
class CircuitBreaker {
  constructor(options = {}) {
    this.failureThreshold = options.failureThreshold || 5;
    this.resetTimeout = options.resetTimeout || 30000; // 30s
    this.state = 'CLOSED'; // CLOSED, OPEN, HALF_OPEN
    this.failures = 0;
    this.lastFailureTime = null;
    this.successThreshold = options.successThreshold || 2;
    this.successCount = 0;
  }

  async execute(fn) {
    if (this.state === 'OPEN') {
      if (Date.now() - this.lastFailureTime > this.resetTimeout) {
        this.state = 'HALF_OPEN';
        this.successCount = 0;
      } else {
        throw new Error('Circuit breaker is OPEN - GitHub API unavailable');
      }
    }

    try {
      const result = await fn();
      this.onSuccess();
      return result;
    } catch (error) {
      this.onFailure();
      throw error;
    }
  }

  onSuccess() {
    if (this.state === 'HALF_OPEN') {
      this.successCount++;
      if (this.successCount >= this.successThreshold) {
        this.state = 'CLOSED';
        this.failures = 0;
      }
    } else {
      this.failures = 0;
    }
  }

  onFailure() {
    this.failures++;
    this.lastFailureTime = Date.now();
    if (this.failures >= this.failureThreshold) {
      this.state = 'OPEN';
    }
  }

  getState() {
    return {
      state: this.state,
      failures: this.failures,
      lastFailure: this.lastFailureTime
    };
  }
}

// Uso en UATRegistration.jsx
const gitHubBreaker = new CircuitBreaker({
  failureThreshold: 3,
  resetTimeout: 60000
});

const fetchWithBreaker = async (url, options) => {
  return gitHubBreaker.execute(() => fetch(url, options));
};
```

- **Impacto**: Alto (Resiliencia, UX)
- **Esfuerzo**: Medio
- **Archivos**: Nuevo `CircuitBreaker.js`, modificar `UATRegistration.jsx`

---

#### 1.4 Idempotencia
- **Estado actual**: Si se hace doble-clic rápido, podría crear 2 requests
- **Problema**: Duplicación de Issues y PRs
- **Solución**: Idempotency key basada en API+Version+Revision

```javascript
// En UATRegistration.jsx
const generateIdempotencyKey = (apiId, version, revision) => {
  const date = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
  return `${apiId}-${version}-${revision}-${date}`;
};

// Antes de disparar workflow
const checkExistingRequest = async (idempotencyKey) => {
  const response = await fetch(
    `${GITHUB_API}/repos/${helixRepo}/issues?labels=uat-request&state=all`,
    { headers: { Authorization: `token ${token}` } }
  );
  const issues = await response.json();

  return issues.find(issue =>
    issue.body.includes(`idempotency_key: ${idempotencyKey}`)
  );
};

// En handleRegister
const existingRequest = await checkExistingRequest(idempotencyKey);
if (existingRequest) {
  if (existingRequest.state === 'open') {
    setError('Ya existe una solicitud en proceso para esta revisión');
    return;
  }
  // Si está cerrada, permitir nuevo registro (nueva revisión del día)
}
```

```yaml
# En process-api-request.yml - Añadir al body del Issue
body: |
  ## API Registration Request

  idempotency_key: ${{ inputs.idempotency_key }}
  request_id: ${{ inputs.request_id }}
  ...
```

- **Impacto**: Alto (Integridad de datos)
- **Esfuerzo**: Bajo
- **Archivos**: `UATRegistration.jsx`, `process-api-request.yml`

---

#### 1.5 Health Checks Pre-Registro
- **Estado actual**: Se asume que GitHub y WSO2-Processor están disponibles
- **Problema**: Fallo tardío si un sistema está caído
- **Solución**: Verificar disponibilidad antes de iniciar

```javascript
// En UATRegistration.jsx
const systemHealthCheck = async () => {
  const checks = {
    github: false,
    processor: false
  };

  try {
    // Check GitHub API
    const ghResponse = await fetch('https://api.github.com/rate_limit', {
      headers: { Authorization: `token ${token}` }
    });
    checks.github = ghResponse.ok &&
      ghResponse.headers.get('x-ratelimit-remaining') > 10;

    // Check si el runner está activo (via workflow reciente)
    const runsResponse = await fetch(
      `${GITHUB_API}/repos/${processorRepo}/actions/runs?per_page=1`,
      { headers: { Authorization: `token ${token}` } }
    );
    const runs = await runsResponse.json();
    if (runs.workflow_runs?.length > 0) {
      const lastRun = new Date(runs.workflow_runs[0].created_at);
      const hourAgo = new Date(Date.now() - 3600000);
      checks.processor = lastRun > hourAgo; // Runner activo en última hora
    }
  } catch (e) {
    console.error('Health check failed:', e);
  }

  return checks;
};

// En handleRegister - antes de iniciar
const health = await systemHealthCheck();
if (!health.github) {
  setError('GitHub API no disponible. Intente más tarde.');
  return;
}
if (!health.processor) {
  setError('Sistema de procesamiento no disponible. Contacte al administrador.');
  return;
}
```

- **Impacto**: Medio (UX, Fail-fast)
- **Esfuerzo**: Bajo
- **Archivos**: `UATRegistration.jsx`

---

#### 1.6 Observabilidad con ELK + Grafana (Stack existente)
- **Estado actual**: `requestId` existe pero no se envía a sistemas de observabilidad
- **Problema**: Difícil correlacionar eventos entre Publisher, WSO2-Processor y GIT-Helix-Processor
- **Solución**: Logs estructurados a ELK + Métricas a Prometheus/Grafana

> **Nota**: No se recomienda OpenTelemetry ya que el stack ELK + Grafana existente cubre las necesidades sin añadir complejidad.

##### 1.6.1 Logs estructurados a Elasticsearch

```yaml
# En workflows - Enviar logs estructurados a ELK
- name: Log to Elasticsearch
  if: always()
  run: |
    curl -sk -X POST "${{ secrets.ELK_ENDPOINT }}/apiops-logs/_doc" \
      -H "Content-Type: application/json" \
      -H "Authorization: ApiKey ${{ secrets.ELK_API_KEY }}" \
      -d '{
        "@timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
        "request_id": "${{ inputs.request_id }}",
        "service": "wso2-processor",
        "action": "export-api",
        "api": {
          "name": "${{ inputs.api_name }}",
          "version": "${{ inputs.api_version }}",
          "subdominio": "${{ inputs.subdominio }}"
        },
        "status": "${{ job.status }}",
        "duration_ms": '$((SECONDS * 1000))',
        "workflow_run_id": "${{ github.run_id }}"
      }'
```

```javascript
// En UATRegistration.jsx - Log de eventos al backend
const logEvent = async (action, status, metadata = {}) => {
  try {
    await fetch('/api/am/publisher/v4/apiops/logs', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        timestamp: new Date().toISOString(),
        request_id: requestId,
        service: 'publisher-ui',
        action,
        status,
        api: { name: api.name, version: api.version },
        ...metadata
      })
    });
  } catch (e) {
    console.warn('Failed to log event:', e);
  }
};

// Uso
await logEvent('registration-started', 'info');
await logEvent('workflow-triggered', 'success', { workflow: 'process-api-request' });
await logEvent('registration-completed', 'success', { duration_ms: Date.now() - startTime });
```

**Consulta en Kibana:**
```
request_id:"REQ-CustomerAPI-1733849234-x7k9"
```

Resultado:
```
10:23:45 | publisher-ui    | registration-started  | info
10:23:46 | publisher-ui    | workflow-triggered    | success
10:23:47 | wso2-processor  | validate-deployment   | success
10:23:52 | wso2-processor  | export-api            | success
10:23:54 | helix-processor | create-issue          | success
10:24:02 | helix-processor | helix-approved        | success
10:24:15 | helix-processor | pr-created            | success
10:24:19 | helix-processor | pr-merged             | success
10:24:20 | publisher-ui    | registration-completed| success
```

##### 1.6.2 Métricas a Prometheus/Grafana

```yaml
# En workflows - Push métricas a Prometheus Pushgateway
- name: Push metrics to Prometheus
  if: always()
  run: |
    cat <<EOF | curl -sk --data-binary @- \
      "${{ secrets.PUSHGATEWAY_URL }}/metrics/job/apiops/instance/${{ github.run_id }}"
    # TYPE apiops_registration_duration_seconds gauge
    apiops_registration_duration_seconds{api="${API_NAME}",version="${API_VERSION}",phase="export"} ${DURATION}
    # TYPE apiops_registration_status gauge
    apiops_registration_status{api="${API_NAME}",version="${API_VERSION}",status="${STATUS}"} 1
    EOF
```

**Dashboard Grafana sugerido:**
```
┌─────────────────────────────────────────────────────────────────┐
│                 APIOPS - Registration Metrics                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Registros/hora      Tiempo promedio      Tasa de éxito         │
│  ┌──────────┐        ┌──────────┐         ┌──────────┐          │
│  │   127    │        │  34.2s   │         │  98.5%   │          │
│  └──────────┘        └──────────┘         └──────────┘          │
│                                                                  │
│  Latencia por fase (p95):                                        │
│  ████████████ export-api: 12.3s                                 │
│  ████ validate: 4.1s                                            │
│  ██████████████████ helix-approval: 18.7s                       │
│                                                                  │
│  Errores por tipo (últimas 24h):                                │
│  • subdominio-not-found: 12                                     │
│  • api-not-deployed: 5                                          │
│  • github-rate-limit: 2                                         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

##### 1.6.3 Alertas recomendadas

```yaml
# alertmanager rules
groups:
  - name: apiops
    rules:
      - alert: APIRegistrationHighFailureRate
        expr: |
          sum(rate(apiops_registration_status{status="failure"}[5m]))
          / sum(rate(apiops_registration_status[5m])) > 0.1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Tasa de fallos de registro > 10%"

      - alert: APIRegistrationSlow
        expr: |
          histogram_quantile(0.95, apiops_registration_duration_seconds) > 120
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Registros tardando más de 2 minutos (p95)"
```

- **Impacto**: Alto (Observabilidad completa sin nuevas herramientas)
- **Esfuerzo**: Medio
- **Archivos**: Workflows, `UATRegistration.jsx`, configuración Grafana/Kibana
- **Prerequisitos**: Acceso a ELK y Prometheus/Pushgateway desde GitHub Actions

---

### 2. SEGURIDAD (Prioridad: CRÍTICA)

#### 2.1 Externalizar Token de GitHub
- **Estado actual**: Token hardcodeado en `apiops-config.js`
- **Problema**: Token expuesto en repositorio (incluso si es privado)
- **Solución**: Variables de entorno en runtime

```javascript
// apiops-config.js - NUEVO
window.APIOpsConfig = {
  github: {
    // Token se inyecta en runtime, no en código
    token: null, // Se configura via API de WSO2
    processorRepo: 'ISAngelRivera/WSO2-Processor',
    helixRepo: 'ISAngelRivera/GIT-Helix-Processor'
  }
};

// En WSO2 - endpoint seguro para obtener token
// /api/am/publisher/v4/settings/apiops-token
// Devuelve token desde vault/secrets manager
```

**Alternativa mejor - GitHub App:**
```javascript
// Usar GitHub App en lugar de PAT
// 1. Crear GitHub App con permisos mínimos
// 2. Generar JWT y obtener installation token
// 3. Tokens son efímeros (1 hora)
```

- **Impacto**: Crítico (Seguridad)
- **Esfuerzo**: Medio
- **Archivos**: `apiops-config.js`, backend WSO2

---

#### 2.2 Firma de Requests
- **Descripción**: Firmar digitalmente los requests desde WSO2-Processor
- **Valor**: Prevenir requests falsificados
- **Complejidad**: Media

---

#### 2.3 Audit Log Inmutable
- **Descripción**: Log append-only de todas las operaciones
- **Valor**: Cumplimiento normativo
- **Complejidad**: Alta

---

### 3. CALIDAD DE CÓDIGO (Prioridad: MEDIA)

#### 3.1 Consolidar Funciones Duplicadas
- **Estado actual**: `extractErrorFromJobs()` y `extractHelixError()` hacen casi lo mismo
- **Solución**: Refactorizar a función genérica

```javascript
// Función unificada
const extractWorkflowError = (jobs, errorPatterns = []) => {
  const defaultPatterns = [
    /Error:/i,
    /failed:/i,
    /exception:/i,
    /❌/
  ];

  const patterns = [...defaultPatterns, ...errorPatterns];

  for (const job of jobs) {
    if (job.conclusion === 'failure') {
      for (const step of job.steps || []) {
        if (step.conclusion === 'failure') {
          // Buscar en logs del step
          const logs = await fetchStepLogs(job.id, step.number);
          for (const pattern of patterns) {
            const match = logs.match(pattern);
            if (match) return match[0];
          }
          return `Fallo en paso: ${step.name}`;
        }
      }
      return `Fallo en job: ${job.name}`;
    }
  }
  return 'Error desconocido en el workflow';
};
```

- **Archivos**: `UATRegistration.jsx`

---

#### 3.2 Centralizar Configuración
- **Estado actual**: Magic numbers dispersos (`maxAttempts = 60`, `pollInterval = 3000`)
- **Solución**: Mover todo a `apiops-config.js`

```javascript
// apiops-config.js
window.APIOpsConfig = {
  github: { /* ... */ },
  polling: {
    maxAttempts: 60,
    baseInterval: 3000,
    maxInterval: 30000,
    backoffMultiplier: 2
  },
  timeouts: {
    workflowStart: 30000,  // 30s para que inicie el workflow
    totalProcess: 180000   // 3min máximo total
  },
  ui: {
    showDebugInfo: false,
    autoRefreshInterval: 60000
  }
};
```

---

#### 3.3 Scripts Bash - Librería Común
- **Estado actual**: OAuth2 token retrieval duplicado en múltiples scripts
- **Solución**: Crear `lib/wso2-auth.sh`

```bash
#!/bin/bash
# scripts/lib/wso2-auth.sh

get_oauth_token() {
  local scope="${1:-apim:api_view}"

  CLIENT_RESP=$(curl -sk -X POST \
    -H "Authorization: Basic YWRtaW46YWRtaW4=" \
    -H "Content-Type: application/json" \
    -d '{"callbackUrl":"https://localhost","clientName":"script_client","owner":"admin","grantType":"password","saasApp":true}' \
    "https://localhost:9443/client-registration/v0.17/register")

  CID=$(echo "$CLIENT_RESP" | jq -r ".clientId")
  CS=$(echo "$CLIENT_RESP" | jq -r ".clientSecret")

  TOKEN=$(curl -sk -X POST \
    -H "Authorization: Basic $(echo -n "${CID}:${CS}" | base64)" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=password&username=admin&password=admin&scope=${scope}" \
    "https://localhost:9443/oauth2/token" | jq -r ".access_token")

  echo "$TOKEN"
}

# Uso en otros scripts:
# source "$(dirname "$0")/lib/wso2-auth.sh"
# TOKEN=$(get_oauth_token "apim:api_view apim:api_create")
```

---

### 4. TESTING (Prioridad: MEDIA-ALTA)

#### 4.1 Unit Tests para UATRegistration.jsx
```javascript
// __tests__/UATRegistration.test.jsx
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import UATRegistration from '../UATRegistration';

// Mock de fetch
global.fetch = jest.fn();

describe('UATRegistration', () => {
  beforeEach(() => {
    fetch.mockClear();
  });

  test('shows register button when API is published and deployed', async () => {
    const mockApi = {
      id: 'test-api-id',
      name: 'TestAPI',
      version: '1.0.0',
      lifeCycleStatus: 'PUBLISHED',
      additionalProperties: [{ name: 'subdominio', value: 'test-domain' }]
    };

    render(<UATRegistration api={mockApi} />);

    expect(screen.getByText('Registrar en UAT')).toBeInTheDocument();
  });

  test('shows error when API has no subdominio', async () => {
    const mockApi = {
      id: 'test-api-id',
      name: 'TestAPI',
      version: '1.0.0',
      lifeCycleStatus: 'PUBLISHED',
      additionalProperties: []
    };

    render(<UATRegistration api={mockApi} />);
    fireEvent.click(screen.getByText('Registrar en UAT'));

    await waitFor(() => {
      expect(screen.getByText(/subdominio/i)).toBeInTheDocument();
    });
  });

  test('disables button during registration', async () => {
    // Mock workflow trigger
    fetch.mockResolvedValueOnce({ ok: true });

    const mockApi = { /* ... */ };
    render(<UATRegistration api={mockApi} />);

    fireEvent.click(screen.getByText('Registrar en UAT'));

    expect(screen.getByRole('button')).toBeDisabled();
  });
});
```

#### 4.2 Integration Tests para Workflows
```yaml
# .github/workflows/test-integration.yml
name: Integration Tests
on:
  pull_request:
    paths:
      - '.github/workflows/**'

jobs:
  test-workflow:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Test process-api-request
        uses: nektos/act@v0.2.49
        with:
          job: process-request
          eventPath: .github/test-events/api-request.json
```

---

### 5. OBSERVABILIDAD (Prioridad: MEDIA)

> **Stack existente**: ELK (Elasticsearch + Kibana) + Prometheus/Grafana
>
> No se recomienda OpenTelemetry - añadiría complejidad sin valor adicional.

#### 5.1 Integración con ELK existente
- Ver sección 1.6.1 para implementación detallada de logs estructurados
- Crear índice `apiops-*` en Elasticsearch
- Dashboard en Kibana para correlacionar por `request_id`

#### 5.2 Integración con Grafana existente
- Ver sección 1.6.2 para implementación de métricas
- Configurar Pushgateway para recibir métricas desde GitHub Actions
- Dashboard con métricas de latencia y tasa de éxito

#### 5.3 Dashboard de Estado de APIs
- **Descripción**: Vista global de todas las APIs y su estado de registro en UAT/NFT/PRO
- **Valor**: Visibilidad para gestores y equipos de soporte
- **Implementación**: Panel en Grafana con datos de Elasticsearch
- **Complejidad**: Media

#### 5.4 SLA Dashboard
- **Descripción**: Medir tiempo promedio de cada fase del registro
- **Valor**: Identificar cuellos de botella y cumplimiento de SLAs
- **Métricas clave**:
  - p50, p95, p99 de tiempo total de registro
  - Tiempo por fase (export, validation, helix-approval, merge)
  - Tasa de éxito por subdominio
- **Complejidad**: Media

---

### 6. LOGGING (Prioridad: BAJA)

#### 6.1 Logging Estructurado en Workflows
```yaml
# Cambiar de:
echo "Error: API not found"

# A:
echo '{"level":"error","message":"API not found","api_id":"${{ inputs.api_id }}","timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}'
```

#### 6.2 Eliminar `|| true` silenciosos
```yaml
# Cambiar de:
some_command || true

# A:
some_command || {
  echo '{"level":"warn","message":"Command failed but continuing","command":"some_command"}'
}
```

---

## PARTE 2: IDEAS DE EVOLUCIÓN FUTURA

Mejoras que añaden funcionalidad nueva al sistema.

---

### Registro UAT - Mejoras UX

| Mejora | Descripción | Valor | Complejidad |
|--------|-------------|-------|-------------|
| Mostrar CRQ | Mostrar número CHG0012345 en la UI | Seguimiento manual | Baja |
| Notificaciones | Email/Slack cuando cambia estado | No estar pendiente de UI | Media |
| Historial | Ver todos los intentos de registro | Auditoría | Baja |
| Reintentar desde punto de fallo | Si falla en paso X, reintentar desde X | Ahorra tiempo | Alta |

---

### Registro NFT y PRO

| Mejora | Descripción | Valor | Complejidad |
|--------|-------------|-------|-------------|
| Flujo NFT | Similar a UAT con validadores más estrictos | Reutilización | Media |
| Promoción UAT→NFT | Usar lo que ya está en Git | No re-exportar | Media |
| Aprobación multi-nivel PRO | Técnica + negocio | Cumplimiento | Alta |
| Ventanas de despliegue | Solo ciertos horarios para PRO | Control de cambios | Media |

---

### Git / Estructura

| Mejora | Descripción | Valor | Complejidad |
|--------|-------------|-------|-------------|
| Limpieza de ramas | Job para eliminar ramas huérfanas | Repo limpio | Baja |
| Versionado semántico | Sugerir siguiente versión automáticamente | Consistencia | Alta |
| Diff entre revisiones | Mostrar cambios antes de registrar | Visibilidad | Media |

---

### Validaciones / Linting

| Mejora | Descripción | Valor | Complejidad |
|--------|-------------|-------|-------------|
| Validaciones por dominio | Cada dominio define sus reglas | Flexibilidad | Media |
| Breaking changes | Detectar incompatibilidades | Prevención | Alta |
| Score de calidad | Dar score numérico además de pass/fail | Mejora continua | Media |

---

### Integraciones

| Mejora | Descripción | Valor | Complejidad |
|--------|-------------|-------|-------------|
| Slack bot | Consultar estado y aprobar desde Slack | Productividad | Media |
| Adaptadores multi-vendor | Apigee-Processor, Kong-Processor | Vendor agnostic | Media/vendor |
| Contract testing | Validar integración entre Processors | Estabilidad | Media |
| Multi-tenant | Múltiples organizaciones | Escalabilidad | Alta |

---

### UI / UX

| Mejora | Descripción | Valor | Complejidad |
|--------|-------------|-------|-------------|
| Modo oscuro | Tema oscuro para la UI | Preferencia usuarios | Baja |

---

## RESUMEN DE PRIORIDADES

### Fase 1 - Crítico (Seguridad + Quick Wins)
1. Externalizar token de GitHub
2. Exponential backoff en polling
3. Idempotencia de requests

### Fase 2 - Alta Prioridad (Resiliencia)
4. Circuit breaker
5. Health checks pre-registro
6. Dead Letter Queue

### Fase 3 - Media Prioridad (Calidad)
7. Consolidar código duplicado
8. Centralizar configuración
9. Unit tests para React

### Fase 4 - Observabilidad (usando stack existente)
10. Logs estructurados a ELK (Kibana)
11. Métricas a Prometheus/Grafana
12. Dashboards y alertas

---

## MATRIZ DE IMPACTO VS ESFUERZO

```
IMPACTO
   ^
   │  ┌─────────────────┬─────────────────┐
   │  │ QUICK WINS      │ PROYECTOS CLAVE │
   │  │                 │                 │
   │  │ • Backoff       │ • Token externo │
   │  │ • Idempotencia  │ • Circuit break │
   │  │ • Health checks │ • DLQ           │
   │  │ • Config central│ • Logs a ELK    │
   │  ├─────────────────┼─────────────────┤
   │  │ RELLENAR        │ EVITAR          │
   │  │                 │                 │
   │  │ • Modo oscuro   │ • Multi-tenant  │
   │  │ • Limpieza ramas│ • Sem. version  │
   │  │ • Métricas Graf.│ • Breaking chgs │
   │  └─────────────────┴─────────────────┘
   └──────────────────────────────────────> ESFUERZO
         BAJO                    ALTO
```

> **Decisión de stack**: Se usa ELK + Grafana existente en lugar de OpenTelemetry para evitar añadir complejidad innecesaria.

---

## NOTAS

- Las complejidades son estimaciones que deben validarse
- Priorizar según valor de negocio vs esfuerzo
- Revisar este documento después de cada sprint
- La Parte 1 debe completarse antes de considerar producción

---

*Última actualización: 2025-12-10*
*Versión: 2.0 - Incluye mejoras técnicas de la revisión arquitectónica*
