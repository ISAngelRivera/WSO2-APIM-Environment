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

## Lifecycle Customizado

Este entorno incluye un lifecycle extendido para soportar el flujo APIOps:

```
                    ┌──────────────┐
                    │   Created    │
                    └──────┬───────┘
                           │ Publish
                           ▼
                    ┌──────────────┐
              ┌─────│  Published   │─────┐
              │     └──────┬───────┘     │
              │            │             │
           Block      Register UAT    Deprecate
              │            │             │
              ▼            ▼             ▼
        ┌──────────┐ ┌─────────────┐ ┌───────────┐
        │ Blocked  │ │Registering  │ │Deprecated │
        └──────────┘ │    UAT      │ └───────────┘
                     └──────┬──────┘
                            │ Complete
                            ▼
                     ┌─────────────┐
                     │Registered   │
                     │    UAT      │
                     └──────┬──────┘
                            │ Promote to NFT
                            ▼
                     ┌─────────────┐
                     │ Promoting   │
                     │    NFT      │
                     └──────┬──────┘
                            │ Complete
                            ▼
                     ┌─────────────┐
                     │Registered   │
                     │    NFT      │
                     └──────┬──────┘
                            │ Promote to PRO
                            ▼
                     ┌─────────────┐
                     │ Promoting   │
                     │    PRO      │
                     └──────┬──────┘
                            │ Complete
                            ▼
                     ┌─────────────┐
                     │ Production  │
                     └─────────────┘
```

### Estados del Lifecycle

| Estado | Descripción |
|--------|-------------|
| Created | API recién creado, pendiente de configuración |
| Published | API publicado en el Gateway, listo para registrar en Git |
| Registering UAT | (Transitorio) Registrando en repositorio Git - UAT |
| Registered UAT | API registrado en Git para UAT |
| Promoting NFT | (Transitorio) Promoviendo a NFT |
| Registered NFT | API registrado en Git para NFT |
| Promoting PRO | (Transitorio) Promoviendo a Producción |
| Production | API en producción |

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

## Próximos Pasos

- [ ] Configurar webhook para eventos de lifecycle
- [ ] Integrar con WSO2-Processor
- [ ] Añadir APIs de prueba adicionales
