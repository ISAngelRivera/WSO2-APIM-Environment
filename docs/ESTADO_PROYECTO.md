# Estado del Proyecto APIOps - WSO2 APIM

**Última actualización:** 2024-12-04
**Versión WSO2 APIM:** 4.5.0

## Objetivo Principal

Crear un sistema APIOps que integre:
1. **WSO2 API Manager** - Gestión de APIs
2. **Git** - Versionado de definiciones de API
3. **Helix (ITSM)** - Gestión de cambios (CRQ)

### Flujo Deseado
```
Usuario hace clic en "Registrar en UAT"
    → Exportar API a Git (PR)
    → Validar definición
    → Crear CRQ en Helix
    → Esperar aprobación CRQ
    → Importar API en UAT
    → Notificar al usuario
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

### Pendiente

1. **Workflow Executor JAR** (backend)
   - Interceptar evento de publicación de API
   - Llamar a GitHub API para crear PR
   - Llamar a Helix API para crear CRQ
   - Actualizar estado en frontend

3. **WSO2-Processor** (GitHub Actions)
   - Escuchar eventos de PR
   - Validar definición de API
   - Notificar resultado

4. **GIT-Helix-Processor**
   - Integración bidireccional Git ↔ Helix

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

1. **Probar el componente UATRegistration**
   - Limpiar caché del navegador (Ctrl+Shift+Delete / Cmd+Shift+Delete)
   - Acceder a https://localhost:9443/publisher
   - Ir a una API publicada → Lifecycle
   - El botón "Registrar en UAT" debería aparecer

2. **Si funciona:** Implementar el backend (Workflow Executor JAR)

3. **Si no funciona:**
   - Revisar consola del navegador (F12 → Console)
   - Verificar Network tab para ver si el bundle se carga
   - Comprobar que el contenedor tiene el bundle correcto

## Problema del Hash del Bundle (Lección Aprendida)

El `index.jsp` del Publisher (en `pages/`) no está en nuestro dropin - solo montamos `dist/`.
El JSP contiene el hash hardcodeado del bundle original de WSO2.

**Solución temporal:** Copiar nuestro bundle con el nombre esperado:
```bash
cd publisher-dropin
cp index.NUEVO_HASH.bundle.js index.HASH_ORIGINAL.bundle.js
```

**Cómo encontrar los hashes:**
```bash
# Hash que espera WSO2 (en el contenedor):
docker exec wso2-apim grep "index\." /home/wso2carbon/wso2am-4.5.0/repository/deployment/server/webapps/publisher/site/public/pages/index.jsp

# Hash de nuestro bundle:
ls publisher-dropin/index.*.bundle.js
```
