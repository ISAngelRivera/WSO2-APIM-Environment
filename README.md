# WSO2-APIM-Environment

Entorno de desarrollo Docker para WSO2 API Manager 4.5.0 con lifecycle customizado para APIOps.

## Requisitos

- Docker Desktop
- 4GB RAM mínimo disponible para Docker

## Inicio Rápido

```bash
# 1. Clonar el repositorio
git clone https://github.com/ISAngelRivera/WSO2-APIM-Environment.git
cd WSO2-APIM-Environment

# 2. Iniciar el entorno
./scripts/start.sh

# 3. Esperar a que APIM esté listo (~2-3 minutos)
./scripts/wait-for-apim.sh

# 4. Configurar (primera vez)
./scripts/setup-all.sh
```

## URLs de Acceso

| Portal | URL | Credenciales |
|--------|-----|--------------|
| Publisher | https://localhost:9443/publisher | admin / admin |
| DevPortal | https://localhost:9443/devportal | admin / admin |
| Carbon Admin | https://localhost:9443/carbon | admin / admin |

## Flujo APIOps

Este entorno implementa un flujo APIOps completo usando el **lifecycle estándar de WSO2** más un **componente React personalizado** para el registro en UAT:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          FLUJO COMPLETO (~30-45s)                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  1. Publisher Portal                                                    │
│     └── Usuario hace clic en "Registrar en UAT"                        │
│                                                                         │
│  2. WSO2-Processor (self-hosted runner) [~10s]                         │
│     ├── Valida API desplegada                                          │
│     ├── Exporta API con apictl                                         │
│     └── Valida subdominio configurado                                  │
│                                                                         │
│  3. GIT-Helix-Processor [~15s]                                         │
│     ├── Valida subdominio existe                                       │
│     ├── Crea Issue (cola de solicitudes)                               │
│     ├── Guarda artifact (export API)                                   │
│     └── Simula aprobación Helix                                        │
│                                                                         │
│  4. on-helix-approval [~15s]                                           │
│     ├── Crea PR en repo del subdominio                                 │
│     ├── Merge automático                                               │
│     └── Cierra Issue                                                   │
│                                                                         │
│  5. Publisher muestra "API registrada correctamente"                   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Lifecycle Estándar + Componente UAT

| Estado WSO2 | Componente React | Descripción |
|-------------|------------------|-------------|
| Created | - | API recién creado |
| Published | Muestra "Registrar en UAT" | API listo para registro |
| Published | Estado: Registrado | API ya registrado en Git |

**Nota:** El registro en UAT NO cambia el estado del lifecycle de WSO2. Se gestiona enteramente a través del componente React UATRegistration.

## Scripts Disponibles

| Script | Descripción |
|--------|-------------|
| `./scripts/start.sh` | Inicia el entorno |
| `./scripts/stop.sh` | Detiene el entorno (preserva datos) |
| `./scripts/reset.sh` | Elimina todo y reinicia desde cero |
| `./scripts/wait-for-apim.sh` | Espera a que APIM esté listo |
| `./scripts/setup-all.sh` | Ejecuta toda la configuración inicial |
| `./scripts/verify-lifecycle.sh` | Verifica el lifecycle customizado |
| `./scripts/create-sample-api.sh` | Crea PizzaAPI de prueba |

## Estructura del Proyecto

```
WSO2-APIM-Environment/
├── docker-compose.yml          # Definición del contenedor
├── lifecycle/
│   └── APILifeCycle.xml        # Lifecycle customizado
├── scripts/
│   ├── start.sh                # Iniciar entorno
│   ├── stop.sh                 # Detener entorno
│   ├── reset.sh                # Reset completo
│   ├── wait-for-apim.sh        # Esperar inicio
│   ├── setup-all.sh            # Configuración inicial
│   ├── verify-lifecycle.sh     # Verificar lifecycle
│   └── create-sample-api.sh    # Crear API de prueba
└── config/                     # (Futuro) Configuraciones adicionales
```

## Volúmenes Docker

Los datos se persisten en volúmenes Docker:

| Volumen | Contenido |
|---------|-----------|
| `wso2-apim-data` | Base de datos H2 interna |
| `wso2-apim-registry` | Registry y lifecycles |
| `wso2-apim-logs` | Logs de la aplicación |

## Probar el Flujo APIOps

1. **Accede al Publisher**: https://localhost:9443/publisher
2. **Busca "PizzaAPI"** (creada automáticamente)
3. **Ve a la pestaña "Lifecycle"**
4. **Verás el botón "Register UAT"**

Al pulsar el botón, el estado cambiará a "Registering UAT". En el MVP, el workflow externo (WSO2-Processor → GIT-Helix-Processor) cambiará el estado a "Registered UAT" cuando complete el registro.

## Integración con APIOps

Este entorno se integra con:

- **WSO2-Processor**: Recibe eventos de lifecycle
- **GIT-Helix-Processor**: Registra APIs en repositorios Git
- **Informatica-DevOps**: Repositorio de ejemplo para dominio Informática
- **Finanzas-Pagos**: Repositorio de ejemplo para dominio Finanzas

## Desarrollo del Publisher (APIOps)

### Después de modificar el código del Publisher

Cada vez que se modifica el código fuente del Publisher (UATRegistration.jsx, etc.), se debe:

```bash
# 1. Compilar el Publisher
cd wso2-source/apim-apps/portals/publisher/src/main/webapp
pnpm run build:prod

# 2. Copiar los bundles al directorio montado
rm -rf ../../../../../../publisher-dropin/*
cp -r site/public/dist/* ../../../../../../publisher-dropin/

# 3. Actualizar el hash en index.jsp (buscar el nuevo hash)
ls site/public/dist/index.*.bundle.js
# Editar publisher-dropin-pages/index.jsp con el nuevo hash

# 4. Reiniciar WSO2 para limpiar caché
docker stop wso2-apim && docker start wso2-apim
```

### Reset completo (limpia volúmenes)

Cuando se necesita un reset completo (volúmenes corruptos, errores de metadata, etc.):

```bash
# Esto elimina TODAS las APIs y datos
docker compose down -v
docker compose up -d

# Esperar a que esté listo
./scripts/wait-for-apim.sh

# Recrear las APIs de prueba
./scripts/create-test-apis.sh
```

### APIs de Prueba Requeridas

Después de un reset de volúmenes, ejecutar `./scripts/create-test-apis.sh` que crea:

| Subdominio | APIs | Descripción |
|------------|------|-------------|
| rrhh-empleados | EmployeeAPI v1.0, v2.0 | Con revisiones, subdominio configurado |
| finanzas-pagos | PaymentAPI v1.0, v2.0, InvoiceAPI v1.0 | Con revisiones, subdominio configurado |
| (ninguno) | TestAPI v1.0 | Sin subdominio - para probar validación |

Esto asegura:
- 3+ APIs por cada repositorio de subdominio
- Al menos una API con versión 2.x y revisiones
- Una API sin subdominio para validar errores

## Troubleshooting

### El contenedor no arranca
```bash
# Ver logs
docker compose logs -f

# Verificar recursos Docker
docker system df
```

### El lifecycle no muestra los nuevos estados
```bash
# Reiniciar el contenedor
docker compose restart

# O hacer reset completo
./scripts/reset.sh
```

### Error de memoria
WSO2 APIM requiere al menos 2GB de RAM. Aumenta la memoria asignada a Docker Desktop.

### Error "metadata corrupted" o archivo no encontrado
```bash
# Reset completo con limpieza de volúmenes
docker compose down -v
docker compose up -d
./scripts/create-test-apis.sh
```

### El navegador no muestra los cambios del Publisher
1. Abrir DevTools (F12)
2. Pestaña Network > marcar "Disable cache"
3. Click derecho en recargar > "Empty Cache and Hard Reload"

O usar ventana de incógnito.

## Estado del Proyecto

### Completado (2025-12-09)

- [x] Componente UATRegistration en Publisher
- [x] Self-hosted runner en Docker
- [x] WSO2-Processor: extrae APIs y valida
- [x] GIT-Helix-Processor: sistema de Issues + simulación Helix
- [x] on-helix-approval: crea PR + auto-merge
- [x] Polling en dos fases en Publisher
- [x] Flujo end-to-end funcional (~30-45 segundos)
- [x] Escalabilidad para 2500+ APIs (requestId único)
- [x] Manejo de errores específicos en UI

### Pendiente

- [ ] Integración real con Helix ITSM (actualmente simulado)
- [ ] Gestión de tokens por usuario (OAuth federation)
- [ ] Linters especializados (Spectral, seguridad)

## Documentación Detallada

Ver [docs/ESTADO_PROYECTO.md](docs/ESTADO_PROYECTO.md) para documentación completa del proyecto.
