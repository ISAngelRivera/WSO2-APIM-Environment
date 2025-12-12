# Futuras Mejoras - APIOps

Mejoras tecnicas identificadas y evoluciones futuras del sistema.

---

## PARTE 1: MEJORAS TECNICAS PRIORIZADAS

### 1. Arquitectura y Resiliencia (Alta)

| Mejora | Descripcion | Impacto | Esfuerzo |
|--------|-------------|---------|----------|
| **Retry con Backoff** | Exponential backoff en polling (evita sobrecarga GitHub API) | Alto | Bajo |
| **Dead Letter Queue** | Reprocesamiento automatico de Issues fallidos | Alto | Medio |
| **Circuit Breaker** | Detectar cuando GitHub esta caido y fail-fast | Alto | Medio |
| **Idempotencia** | Evitar duplicacion por doble-clic (key: API+Version+Date) | Alto | Bajo |
| **Health Checks** | Verificar GitHub y runner antes de iniciar | Medio | Bajo |

### 2. Seguridad (Critica)

| Mejora | Descripcion | Impacto | Esfuerzo |
|--------|-------------|---------|----------|
| **Externalizar Token** | Mover token de `apiops-config.js` a vault/secrets | Critico | Medio |
| **GitHub App** | Usar App con tokens efimeros (1h) en lugar de PAT | Alto | Alto |
| **Firma de Requests** | Firmar digitalmente requests desde WSO2-Processor | Alto | Medio |
| **Audit Log** | Log inmutable append-only de operaciones | Alto | Alto |

### 3. Calidad de Codigo (Media)

| Mejora | Descripcion | Impacto | Esfuerzo |
|--------|-------------|---------|----------|
| **Consolidar duplicados** | `extractErrorFromJobs()` y `extractHelixError()` | Medio | Bajo |
| **Centralizar config** | Magic numbers a `apiops-config.js` | Medio | Bajo |
| **Libreria bash** | `lib/wso2-auth.sh` para OAuth2 comun | Bajo | Bajo |

### 4. Testing (Media-Alta)

| Mejora | Descripcion | Impacto | Esfuerzo |
|--------|-------------|---------|----------|
| **Unit Tests React** | Tests para UATRegistration.jsx | Alto | Medio |
| **Integration Tests** | Tests de workflows con nektos/act | Alto | Alto |
| **E2E automatizados** | Pipeline CI para pruebas completas | Alto | Alto |

### 5. Observabilidad (Media)

| Mejora | Descripcion | Impacto | Esfuerzo |
|--------|-------------|---------|----------|
| **Logs a ELK** | Logs estructurados con `request_id` a Elasticsearch | Alto | Medio |
| **Metricas Grafana** | Push metricas a Prometheus/Pushgateway | Alto | Medio |
| **Dashboard APIs** | Vista global de estado de APIs por entorno | Medio | Medio |
| **SLA Dashboard** | p50/p95/p99 de tiempos por fase | Medio | Medio |

---

## PARTE 2: EVOLUCIONES FUTURAS

### Registro UAT - Mejoras UX

| Mejora | Descripcion | Valor |
|--------|-------------|-------|
| Mostrar CRQ | Numero CHG0012345 en la UI | Seguimiento |
| Notificaciones | Email/Slack cuando cambia estado | Productividad |
| Historial | Ver todos los intentos de registro | Auditoria |
| Reintentar parcial | Si falla en paso X, reintentar desde X | Eficiencia |

### Registro NFT y PRO

| Mejora | Descripcion | Valor |
|--------|-------------|-------|
| Flujo NFT | Similar a UAT con validadores estrictos | Reutilizacion |
| Promocion UAT->NFT | Usar lo que ya esta en Git | No re-exportar |
| Aprobacion multi-nivel | Tecnica + negocio para PRO | Cumplimiento |
| Ventanas despliegue | Horarios especificos para PRO | Control |

### Git / Estructura

| Mejora | Descripcion | Valor |
|--------|-------------|-------|
| Limpieza ramas | Job para eliminar ramas huerfanas | Repo limpio |
| Versionado semantico | Sugerir siguiente version | Consistencia |
| Diff revisiones | Mostrar cambios antes de registrar | Visibilidad |

### Validaciones

| Mejora | Descripcion | Valor |
|--------|-------------|-------|
| Reglas por dominio | Cada dominio define sus validaciones | Flexibilidad |
| Breaking changes | Detectar incompatibilidades | Prevencion |
| Score calidad | Puntuacion numerica ademas de pass/fail | Mejora continua |

### Integraciones

| Mejora | Descripcion | Valor |
|--------|-------------|-------|
| Slack bot | Consultar estado y aprobar desde Slack | Productividad |
| Multi-vendor | Apigee-Processor, Kong-Processor | Vendor agnostic |
| Contract testing | Validar integracion entre Processors | Estabilidad |
| Multi-tenant | Multiples organizaciones | Escalabilidad |

---

## MATRIZ IMPACTO VS ESFUERZO

```
IMPACTO
   ^
   |  QUICK WINS          PROYECTOS CLAVE
   |  - Backoff           - Token externo
   |  - Idempotencia      - Circuit breaker
   |  - Health checks     - DLQ
   |  - Config central    - Logs a ELK
   |
   |  RELLENAR            EVITAR (por ahora)
   |  - Limpieza ramas    - Multi-tenant
   |  - Metricas          - Semantic version
   +----------------------------------------> ESFUERZO
         BAJO                    ALTO
```

---

## FASES SUGERIDAS

### Fase 1 - Critico (Pre-produccion)
1. Externalizar token de GitHub
2. Exponential backoff en polling
3. Idempotencia de requests

### Fase 2 - Resiliencia
4. Circuit breaker
5. Health checks pre-registro
6. Dead Letter Queue

### Fase 3 - Calidad
7. Consolidar codigo duplicado
8. Centralizar configuracion
9. Unit tests para React

### Fase 4 - Observabilidad
10. Logs estructurados a ELK
11. Metricas a Prometheus/Grafana
12. Dashboards y alertas

---

*Stack recomendado: ELK + Grafana existente (no OpenTelemetry)*
