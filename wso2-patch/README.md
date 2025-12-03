# WSO2 APIM - UAT Registration Feature

## Descripción

Este parche añade una funcionalidad de "Registro en UAT" a la página de Lifecycle del Publisher Portal de WSO2 API Manager.

## Archivos incluidos

1. **UATRegistration.jsx** - Nuevo componente React
   - Ubicación: `portals/publisher/src/main/webapp/source/src/app/components/Apis/Details/LifeCycle/Components/`
   - Funcionalidad: Permite registrar APIs en entorno UAT con seguimiento de estado

2. **LifeCycle.jsx** - Modificación mínima
   - Se añade import del componente UATRegistration
   - Se renderiza el componente entre LifeCycleUpdate y LifeCycleHistory
   - Solo se muestra para APIs (no API Products ni MCP Servers)

## Características

- Botón "Registrar en UAT" visible cuando la API está en estado Published
- Seguimiento de estados: Iniciando → Exportando → Validando → Solicitando CRQ → CRQ Pendiente → Registrando → Registrada
- Posibilidad de cancelar durante el proceso
- Persistencia de estado en localStorage
- Diálogo de confirmación para cancelación
- Alertas de éxito/error
- Stepper visual del progreso
- Internacionalización con react-intl

## Cómo aplicar

```bash
cd apim-apps
git apply uat-registration-feature.patch
```

## Cómo compilar

```bash
cd portals/publisher
npm install
npm run build
```

## Integración Backend (Pendiente)

El componente actualmente simula el flujo. Para producción, necesita:

1. **Endpoint de registro**: POST `/api/am/publisher/v4/apis/{apiId}/register-uat`
2. **Endpoint de estado**: GET `/api/am/publisher/v4/apis/{apiId}/uat-status`
3. **Endpoint de cancelación**: POST `/api/am/publisher/v4/apis/{apiId}/cancel-uat`

## Notas de seguridad

- El componente no ejecuta código externo
- Todas las dependencias son las ya existentes en WSO2 APIM
- El estado se guarda solo en localStorage del navegador
- Las llamadas al backend (cuando se implementen) usarán la autenticación estándar de WSO2

## Licencia

Apache License 2.0 (igual que WSO2 APIM)

---

*Desarrollado por APIOps Team - 2024*
