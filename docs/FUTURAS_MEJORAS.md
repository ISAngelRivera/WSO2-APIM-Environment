# Futuras Mejoras

Documento para registrar ideas y mejoras que no entran en el MVP pero podrían ser útiles en el futuro.

---

## Registro UAT

### Mostrar número de CRQ en la UI
- **Descripción**: Cuando se crea una CRQ en Helix, mostrar el número (ej: CHG0012345) en la UI del Publisher
- **Valor**: El usuario puede hacer seguimiento manual si lo necesita
- **Complejidad**: Baja (solo UI + guardar en metadata)

### Notificaciones
- **Descripción**: Notificar al usuario por email/Slack cuando:
  - Validación falla
  - CRQ es aprobada/rechazada
  - Registro completa
- **Valor**: El usuario no tiene que estar pendiente de la UI
- **Complejidad**: Media

### Historial de registros
- **Descripción**: Ver histórico completo de intentos de registro (no solo el último)
- **Valor**: Auditoría y debugging
- **Complejidad**: Baja

### Reintentar desde punto de fallo
- **Descripción**: Si falla en paso X, poder reintentar desde X en lugar de desde el inicio
- **Valor**: Ahorra tiempo si el fallo fue temporal
- **Complejidad**: Alta (requiere persistencia de estado intermedio)

---

## Registro NFT

### Reutilizar flujo de UAT
- **Descripción**: El flujo de NFT sería similar a UAT pero con:
  - Diferentes validadores (más estrictos)
  - Diferente aprobación en Helix (otro tipo de CRQ)
  - Destino Git diferente (rama/carpeta NFT)
- **Valor**: No reinventar la rueda
- **Complejidad**: Media

### Promoción UAT → NFT
- **Descripción**: Botón para promover una revisión ya registrada en UAT directamente a NFT
- **Valor**: No re-exportar, usar lo que ya está en Git
- **Complejidad**: Media

---

## Registro PRO

### Aprobación multi-nivel
- **Descripción**: PRO podría requerir múltiples aprobaciones (técnica + negocio)
- **Valor**: Cumplimiento normativo
- **Complejidad**: Alta

### Ventanas de despliegue
- **Descripción**: Solo permitir registro a PRO en ciertas ventanas horarias
- **Valor**: Control de cambios
- **Complejidad**: Media

---

## Git / Estructura

### Limpieza automática de ramas antiguas
- **Descripción**: Job programado para eliminar ramas `register/*` huérfanas
- **Valor**: Mantener repo limpio
- **Complejidad**: Baja

### Versionado semántico automático
- **Descripción**: Sugerir siguiente versión basándose en cambios (major/minor/patch)
- **Valor**: Consistencia en versionado
- **Complejidad**: Alta

### Diff entre revisiones
- **Descripción**: Mostrar qué cambió entre rev-3 y rev-4 antes de registrar
- **Valor**: El usuario sabe qué está registrando
- **Complejidad**: Media

---

## Validaciones / Linting

### Validaciones configurables por dominio
- **Descripción**: Cada dominio define qué validaciones aplican
- **Valor**: Flexibilidad
- **Complejidad**: Media

### Validación de breaking changes
- **Descripción**: Detectar si la nueva revisión rompe compatibilidad
- **Valor**: Prevenir problemas en consumidores
- **Complejidad**: Alta

### Score de calidad
- **Descripción**: Además de pass/fail, dar un score (ej: 85/100)
- **Valor**: Mejora continua
- **Complejidad**: Media

---

## UI / UX

### Dashboard de estado
- **Descripción**: Vista global de todas las APIs y su estado de registro
- **Valor**: Visibilidad para gestores
- **Complejidad**: Media

### Modo oscuro
- **Descripción**: Tema oscuro para la UI custom
- **Valor**: Preferencia de usuarios
- **Complejidad**: Baja

---

## Integraciones

### Slack bot
- **Descripción**: Bot para consultar estado y aprobar desde Slack
- **Valor**: No salir de Slack
- **Complejidad**: Media

### Métricas y observabilidad
- **Descripción**: Exportar métricas a Prometheus/Grafana
- **Valor**: Monitorización
- **Complejidad**: Media

---

---

## Arquitectura / Vendor Agnostic

### Adaptadores para otros API Managers
- **Descripción**: Crear `Apigee-Processor`, `Kong-Processor`, etc. que hablen con GIT-Helix-Processor
- **Valor**: Cambiar de WSO2 a otro vendor sin tocar GIT-Helix-Processor
- **Complejidad**: Media por adaptador
- **Patrón**: Cada Processor traduce su formato nativo → formato estándar de request

### Contract Testing entre Processors
- **Descripción**: Tests automáticos que validen que WSO2-Processor genera PRs en el formato esperado por GIT-Helix-Processor
- **Valor**: Evitar roturas silenciosas en la integración
- **Complejidad**: Media

### Multi-tenant / Multi-org
- **Descripción**: Soportar múltiples organizaciones, cada una con su propio GIT-Helix-Processor
- **Valor**: Escalabilidad para empresas grandes
- **Complejidad**: Alta

---

## Seguridad

### Firma de requests
- **Descripción**: Firmar digitalmente los requests desde WSO2-Processor para que GIT-Helix-Processor verifique autenticidad
- **Valor**: Prevenir requests falsificados
- **Complejidad**: Media

### Audit log inmutable
- **Descripción**: Guardar log de todas las operaciones en un sistema append-only (ej: blockchain-lite o S3 con Object Lock)
- **Valor**: Cumplimiento normativo estricto
- **Complejidad**: Alta

---

## Observabilidad

### Tracing distribuido
- **Descripción**: Correlation ID que viaje desde el botón hasta Helix, visible en cada paso
- **Valor**: Debugging de problemas complejos
- **Complejidad**: Media

### SLA Dashboard
- **Descripción**: Medir tiempo promedio de cada paso (export, lint, CRQ approval, etc.)
- **Valor**: Identificar cuellos de botella
- **Complejidad**: Media

---

## Notas

- Las complejidades son estimaciones iniciales
- Priorizar según valor de negocio vs esfuerzo
- Revisar este documento periódicamente

---

*Última actualización: 2024-12-04*
