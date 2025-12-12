# Guia de Instalacion

Manual para levantar el entorno APIOps en cualquier maquina con Docker.

---

## Requisitos

- Docker Desktop
- 4GB RAM minimo para Docker
- GitHub CLI (`gh`) instalado y autenticado
- Token de GitHub con scope `repo`

---

## Pasos de instalacion

### 1. Clonar repositorios

```bash
# Repositorio principal
git clone https://github.com/ISAngelRivera/apim-local-env.git
cd apim-local-env

# (Opcional) Repositorios de dominio para pruebas
git clone https://github.com/ISAngelRivera/apim-domain-rrhh.git /tmp/apim-domain-rrhh
git clone https://github.com/ISAngelRivera/apim-domain-finanzas.git /tmp/apim-domain-finanzas
```

### 2. Configurar credenciales

```bash
# Copiar plantilla
cp .env.example .env

# Editar con tus valores
nano .env
```

Contenido del `.env`:
```bash
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx
GITHUB_OWNER=TuUsuario
GITHUB_REPO=apim-exporter-wso2
```

### 3. Iniciar entorno

```bash
# Levantar servicios
./scripts/start.sh

# Esperar a que WSO2 este listo (~3 minutos)
./scripts/wait-for-apim.sh

# Configuracion inicial (primera vez)
./scripts/setup-all.sh
```

### 4. Verificar instalacion

```bash
# Ejecutar pruebas E2E
./scripts/test-e2e.sh
```

Resultado esperado: `18/18 tests passed`

---

## URLs de acceso

| Portal | URL | Credenciales |
|--------|-----|--------------|
| Publisher | https://localhost:9443/publisher | admin / admin |
| DevPortal | https://localhost:9443/devportal | admin / admin |
| Carbon Admin | https://localhost:9443/carbon | admin / admin |

---

## Comandos utiles

| Comando | Descripcion |
|---------|-------------|
| `./scripts/start.sh` | Iniciar entorno |
| `./scripts/stop.sh` | Detener (preserva datos) |
| `./scripts/reset.sh` | Reset completo |
| `./scripts/test-e2e.sh` | Ejecutar pruebas |
| `./scripts/create-test-apis.sh` | Crear APIs de prueba |

---

## Probar el flujo

1. Accede al Publisher: https://localhost:9443/publisher
2. Busca una API con subdominio configurado (ej: "EmployeeAPI")
3. Ve a la pestana "Lifecycle"
4. Haz clic en "Registrar en UAT"
5. Observa el progreso en el Stepper

---

## Troubleshooting

### El contenedor no arranca
```bash
docker compose logs -f
docker system df  # Verificar espacio
```

### Error de memoria
Aumentar RAM en Docker Desktop (minimo 4GB)

### El runner no se conecta
```bash
docker logs github-runner
# Verificar token en .env
```

### Cache del navegador
1. DevTools (F12) → Network → "Disable cache"
2. Click derecho en recargar → "Empty Cache and Hard Reload"

---

## Reset completo

Si algo falla completamente:

```bash
# Eliminar todo y empezar de cero
docker compose down -v
docker compose up -d
./scripts/wait-for-apim.sh
./scripts/setup-all.sh
```
