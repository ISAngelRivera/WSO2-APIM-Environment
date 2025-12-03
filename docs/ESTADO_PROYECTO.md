# Estado del Proyecto APIOps - WSO2 APIM

**Última actualización:** 2024-12-04 (sesión tarde)
**Versión WSO2 APIM:** 4.5.0

## Objetivo Principal

Crear un sistema APIOps que integre:
1. **WSO2 API Manager** - Gestión de APIs
2. **Git (GitHub)** - Versionado de definiciones de API + Backend (GitHub Actions)
3. **Helix (ITSM)** - Gestión de cambios (CRQ)

### Arquitectura GitOps Aprobada

```
┌─────────────────────┐
│  Publisher Portal   │
│  (UATRegistration)  │
└─────────┬───────────┘
          │ workflow_dispatch
          ▼
┌─────────────────────┐
│   WSO2-Processor    │  ← Repo específico para WSO2
│  (GitHub Actions)   │
│  - Exporta API      │
│  - Crea PR          │
└─────────┬───────────┘
          │ Pull Request con datos planos
          ▼
┌─────────────────────┐
│ GIT-Helix-Processor │  ← Repo genérico (vendor-agnostic)
│  (GitHub Actions)   │
│  - Linters          │
│  - Crea CRQ Helix   │
│  - Almacena API     │
└─────────────────────┘
```

**Decisión clave:** GitHub ES el backend. No hay servidor adicional.

### Flujo Detallado
```
1. Usuario hace clic en "Registrar en UAT"
2. UATRegistration → workflow_dispatch → WSO2-Processor
3. WSO2-Processor:
   - Exporta API de WSO2 (via API REST o apictl)
   - Crea PR en GIT-Helix-Processor con datos PLANOS (no artifact URL)
4. GIT-Helix-Processor (on: pull_request to requests/):
   - Ejecuta linters y validaciones
   - Crea ticket CRQ en Helix
   - Almacena API versionada
5. Notifica resultado al usuario
```

## Estado Actual

### Completado

1. **Componente React UATRegistration** (nativo WSO2)
   - Ubicación: `wso2-source/apim-apps/portals/publisher/src/main/webapp/source/src/app/components/Apis/Details/LifeCycle/Components/UATRegistration.jsx`
   - Estados: IDLE → INITIATING → EXPORTING → VALIDATING → REQUESTING_CRQ → CRQ_PENDING → REGISTERING → REGISTERED
   - Incluye: Stepper visual, diálogo de cancelación, persistencia en localStorage
   - **NOTA:** Actualmente simula el flujo, no hay backend real

2. **Modificación de LifeCycle.jsx**
   - Se añadió import y renderizado del componente UATRegistration
   - Solo visible para APIs publicadas (no Products ni MCP Servers)

3. **Build del Publisher**
   - Compilado con pnpm + frozen-lockfile + ignore-scripts (seguro)
   - Bundle en: `publisher-dropin/` (121MB)
   - Configuración: `transpileOnly: true` en webpack para saltar errores TS preexistentes de WSO2

4. **Docker Compose**
   - Dropin montado en: `/home/wso2carbon/wso2am-4.5.0/repository/deployment/server/webapps/publisher/site/public/dist`

5. **Patch para WSO2**
   - Archivo: `wso2-patch/uat-registration-feature.patch`
   - Listo para enviar como PR al equipo de WSO2

6. **Auditoría de Seguridad**
   - Documentada en: `wso2-patch/SECURITY_AUDIT.md`
   - No hay paquetes comprometidos ni lifecycle hooks maliciosos

7. **Fix del Hash del Bundle** (RESUELTO)
   - **Problema:** El `index.jsp` original de WSO2 buscaba un hash diferente, y webpack genera una tabla de chunks que no coincidía
   - **Solución:** Montar también el `index.jsp` generado por nuestro build:
     ```yaml
     # En docker-compose.yml
     - ./publisher-dropin-pages/index.jsp:/home/wso2carbon/.../pages/index.jsp:ro
     ```
   - Esto asegura que el index.jsp use el hash correcto y la tabla de chunks correcta

8. **Componente UATRegistration visible en UI** ✅
   - Funciona correctamente en APIs publicadas
   - Muestra el flujo de registro UAT con stepper visual

9. **Conexión UATRegistration → GitHub** ✅
   - `triggerGitHubWorkflow()` llama a GitHub API
   - Dispara `workflow_dispatch` en WSO2-Processor
   - Pasa datos de la API (name, version, id, context, user)
   - Token configurable en `localStorage.setItem('github_pat_token', 'ghp_xxx')`

10. **WSO2-Processor** ✅
    - Repo: https://github.com/ISAngelRivera/WSO2-Processor
    - Workflow `receive-uat-request.yml` implementado
    - Exporta API de WSO2 (REST API o mock para demo)
    - Crea PR en GIT-Helix-Processor con datos planos:
      ```
      requests/{request-id}/
      ├── request.yaml      # Metadatos
      ├── api.yaml          # Definición API
      ├── swagger.yaml      # OpenAPI spec
      └── params.yaml       # Config entorno
      ```

11. **GIT-Helix-Processor** ✅
    - Repo: https://github.com/ISAngelRivera/GIT-Helix-Processor
    - Workflow `on-request-pr.yml` implementado
    - Valida con Spectral linter
    - Crea CRQ en Helix (simulado en MVP)
    - Almacena API en `apis/` tras aprobación
    - Comenta en PRs con resultado

### Pendiente

1. **Configurar secrets en GitHub**
   - WSO2-Processor: `WSO2_BASE_URL`, `WSO2_USERNAME`, `WSO2_PASSWORD`, `GIT_HELIX_PAT`
   - GIT-Helix-Processor: `HELIX_API_URL`, `HELIX_TOKEN`

2. **Recompilar Publisher**
   - Ejecutar `./scripts/build-publisher.sh`
   - Reiniciar WSO2 con `docker compose restart wso2-apim`

3. **Probar flujo completo**
   - Configurar token en browser: `localStorage.setItem('github_pat_token', 'ghp_xxx')`
   - Publicar API → Lifecycle → "Registrar en UAT"
   - Verificar workflow en GitHub Actions
   - Verificar PR en GIT-Helix-Processor

4. **Feedback bidireccional** (futuro)
   - Actualizar estado en UATRegistration desde GitHub
   - Opciones: polling, webhooks, o GitHub commit status

## Arquitectura de Archivos

```
WSO2-APIM-Environment/
├── docker-compose.yml          # Configuración Docker con dropin
├── publisher-dropin/           # Bundle compilado del Publisher (121MB)
├── lifecycle/
│   └── APILifeCycle.xml        # Lifecycle customizado con estado UAT
├── wso2-source/
│   └── apim-apps/              # Código fuente clonado de WSO2
│       └── portals/publisher/src/main/webapp/
│           └── source/src/app/components/Apis/Details/LifeCycle/
│               ├── LifeCycle.jsx           # Modificado para incluir UATRegistration
│               └── Components/
│                   └── UATRegistration.jsx # Nuevo componente
├── wso2-patch/
│   ├── uat-registration-feature.patch  # Patch para PR
│   ├── README.md                        # Documentación del patch
│   └── SECURITY_AUDIT.md                # Auditoría de seguridad
├── docs/
│   ├── FUTURAS_MEJORAS.md      # Ideas y mejoras futuras
│   └── ESTADO_PROYECTO.md      # Este archivo
└── scripts/
    ├── build-publisher-safe.sh # Script de build seguro
    └── wait-for-apim.sh        # Esperar a que APIM inicie
```

## Comandos Útiles

```bash
# Iniciar WSO2
docker compose up -d

# Esperar a que esté listo
./scripts/wait-for-apim.sh

# Ver logs
docker logs -f wso2-apim

# Reiniciar con volúmenes limpios (reset total)
docker stop wso2-apim && docker rm wso2-apim
docker volume rm wso2-apim-registry wso2-apim-data
docker compose up -d

# Recompilar Publisher (desde wso2-source/apim-apps/portals/publisher/src/main/webapp)
pnpm install --frozen-lockfile --ignore-scripts
pnpm run build:prod

# Copiar bundle al dropin
cp -r site/public/dist/* /path/to/publisher-dropin/
```

## URLs de Acceso

- **Publisher Portal:** https://localhost:9443/publisher
- **DevPortal:** https://localhost:9443/devportal
- **Carbon Admin:** https://localhost:9443/carbon
- **Credenciales:** admin / admin

## Decisiones Técnicas

1. **pnpm en lugar de npm:** Por seguridad (el usuario rechazó npm por riesgo de supply chain attacks)
2. **frozen-lockfile + ignore-scripts:** Para evitar ejecución de código malicioso
3. **transpileOnly en ts-loader:** WSO2 tiene errores de TypeScript preexistentes que no podemos arreglar
4. **Dropin React nativo:** En lugar de inyección JavaScript vanilla (que no funcionaba bien con React)
5. **Tag v9.3.119:** Usamos un tag estable del repositorio apim-apps

## Contactos

- El usuario tiene contacto con el equipo de desarrollo de WSO2
- Podrían aceptar un PR con el componente UATRegistration si lo hacemos bien

## Próximos Pasos Inmediatos

1. **Configurar secrets en GitHub repos**
   - Ve a Settings → Secrets and variables → Actions
   - WSO2-Processor: `GIT_HELIX_PAT` (token con scope `repo`)
   - Opcional: `WSO2_BASE_URL`, `WSO2_USERNAME`, `WSO2_PASSWORD`

2. **Recompilar Publisher con GitHub integration**
   ```bash
   ./scripts/build-publisher.sh
   docker compose restart wso2-apim
   ```

3. **Configurar token en browser**
   - F12 → Console
   - `localStorage.setItem('github_pat_token', 'ghp_xxx...')`

4. **Probar flujo completo**
   - Publicar una API
   - Ir a Lifecycle → "Registrar en UAT"
   - Verificar:
     - GitHub Actions: https://github.com/ISAngelRivera/WSO2-Processor/actions
     - PR creada: https://github.com/ISAngelRivera/GIT-Helix-Processor/pulls

## Repositorios del Proyecto

| Repositorio | URL | Propósito |
|-------------|-----|-----------|
| WSO2-APIM-Environment | https://github.com/ISAngelRivera/WSO2-APIM-Environment | Código del Publisher y configuración |
| WSO2-Processor | https://github.com/ISAngelRivera/WSO2-Processor | Procesa eventos de WSO2, crea PRs |
| GIT-Helix-Processor | https://github.com/ISAngelRivera/GIT-Helix-Processor | Valida, crea CRQ, almacena APIs |

## Lecciones Aprendidas

### Hash del Bundle
El `index.jsp` del Publisher contiene el hash hardcodeado del bundle.
**Solución:** Montar también `index.jsp` generado por nuestro build.

### GitOps como Backend
GitHub Actions puede servir como "backend" sin necesidad de servidor adicional:
- `workflow_dispatch` recibe eventos
- GitHub API crea PRs
- Workflows procesan PRs automáticamente
