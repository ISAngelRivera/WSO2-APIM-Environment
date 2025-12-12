# Guia de Integracion del Boton UAT

Manual paso a paso para integrar el boton "Registrar en UAT" en WSO2 Publisher.

---

## Que es el sistema de Dropins

WSO2 Publisher es una aplicacion web React. En lugar de modificar el codigo original de WSO2, usamos un sistema de **dropins** que:

1. **No modifica WSO2**: El producto original queda intacto
2. **Hot reload**: Los cambios se aplican sin reiniciar el servidor
3. **Facil rollback**: Si algo falla, solo eliminas los archivos

### Carpetas importantes

```
apim-local-env/
  publisher-dropin/         <- Archivos JavaScript compilados
  publisher-dropin-pages/   <- Pagina index.jsp modificada
  publisher-config/         <- Configuracion (tokens, etc)
  wso2-patch/               <- Codigo fuente del componente
```

---

## Paso 1: Requisitos previos

Antes de empezar, necesitas:

- [ ] Docker Desktop instalado
- [ ] Node.js 18+ instalado
- [ ] pnpm instalado (`npm install -g pnpm`)
- [ ] GitHub CLI instalado (`brew install gh`)
- [ ] Token de GitHub con scope `repo`

---

## Paso 2: Clonar el repositorio de WSO2

El script de build lo hace automaticamente, pero si quieres hacerlo manual:

```bash
cd apim-local-env
mkdir -p wso2-source
cd wso2-source

# Clonar solo la version especifica (mas rapido)
git clone --depth 1 --branch v9.3.119 https://github.com/wso2/apim-apps.git
```

**Nota**: El repositorio pesa ~500MB. El `--depth 1` reduce a ~100MB.

---

## Paso 3: Ubicar el componente React

El componente UATRegistration esta en:

```
wso2-patch/
  source-files/
    UATRegistration.jsx    <- El componente principal (~1,400 lineas)
```

Este archivo debe copiarse a:

```
wso2-source/apim-apps/portals/publisher/src/main/webapp/
  source/src/app/components/Apis/Details/LifeCycle/Components/
    UATRegistration.jsx
```

---

## Paso 4: Modificar LifeCycle.jsx

El archivo `LifeCycle.jsx` es el que muestra la pestana de ciclo de vida.
Hay que importar y usar el nuevo componente:

### 4.1 Anadir el import (linea ~33)

```javascript
import UATRegistration from './Components/UATRegistration';
```

### 4.2 Anadir el componente en el render

Buscar donde termina el componente `LifeCycleUpdate` y anadir:

```javascript
{/* APIOps: Boton de registro en UAT */}
<UATRegistration api={api} />
```

---

## Paso 5: Compilar el Publisher

### Opcion A: Script automatico (recomendado)

```bash
./scripts/build-publisher.sh
```

Este script:
1. Clona el repo de WSO2 (si no existe)
2. Copia el componente UATRegistration
3. Instala dependencias con pnpm
4. Compila para produccion
5. Copia los bundles al dropin

### Opcion B: Compilacion manual

```bash
cd wso2-source/apim-apps/portals/publisher/src/main/webapp

# Instalar dependencias
pnpm install --frozen-lockfile --ignore-scripts

# Compilar (usa ~4GB RAM)
NODE_OPTIONS=--max_old_space_size=4096 pnpm run build:prod

# Los archivos quedan en:
# site/public/dist/index.XXXXX.bundle.js
```

---

## Paso 6: Copiar al dropin

Despues de compilar:

```bash
# Copiar bundles JavaScript
cp -r site/public/dist/* ../../publisher-dropin/

# El archivo principal es algo como:
# index.a1b2c3d4.bundle.js
```

---

## Paso 7: Actualizar index.jsp

El archivo `index.jsp` carga los bundles. Hay que:

1. Actualizar el nombre del bundle (tiene un hash unico)
2. Anadir la carga de `apiops-config.js`

### 7.1 Buscar la linea del bundle

```jsp
<script src="<%= context%>/site/public/dist/index.ANTIGUO.bundle.js"></script>
```

Cambiar `ANTIGUO` por el nuevo hash.

### 7.2 Anadir apiops-config.js

Despues de la linea de `portalSettings.js`:

```jsp
<script src="<%= context%>/site/public/conf/portalSettings.js"></script>
<!-- APIOps Configuration for GitHub integration -->
<script src="<%= context%>/site/public/conf/apiops-config.js"></script>
```

---

## Paso 8: Configurar apiops-config.js

Crear/editar `publisher-config/apiops-config.js`:

```javascript
window.APIOpsConfig = {
    // Debug logging
    debug: true,

    // Configuracion de GitHub
    github: {
        token: 'ghp_TU_TOKEN_AQUI',
        owner: 'TU_USUARIO',
        repo: 'apim-exporter-wso2',
        workflow: 'receive-uat-request.yml',
    },

    // Feature flags
    features: {
        uatRegistration: true,
        nftPromotion: false,
        proPromotion: false,
    },
};
```

**IMPORTANTE**: Este archivo contiene el token de GitHub. No debe commitearse a Git.

---

## Paso 9: Montar en Docker

El `docker-compose.yml` ya tiene los volumenes configurados:

```yaml
volumes:
  # Bundles JavaScript compilados
  - ./publisher-dropin:/home/wso2carbon/.../publisher/site/public/dist:ro

  # Pagina modificada
  - ./publisher-dropin-pages/index.jsp:/home/wso2carbon/.../index.jsp:ro

  # Configuracion runtime
  - ./publisher-config/apiops-config.js:/home/wso2carbon/.../apiops-config.js:ro
```

El `:ro` significa "read-only" (solo lectura).

---

## Paso 10: Reiniciar y probar

```bash
# Si ya tienes WSO2 corriendo
docker compose restart wso2-apim

# O si es la primera vez
docker compose up -d
```

Espera ~2 minutos y accede a:
https://localhost:9443/publisher

---

## Verificacion rapida

1. Ve a cualquier API publicada
2. Haz clic en la pestana "Lifecycle"
3. Deberias ver el boton "Registrar en UAT"

Si no lo ves:

1. Abre DevTools (F12)
2. Ve a Console
3. Busca errores de JavaScript
4. Verifica que el bundle correcto esta cargado en Network

---

## Diagrama del flujo

```
Tu maquina                    Docker                      WSO2 Publisher
    |                            |                              |
    |  publisher-dropin/         |                              |
    +--------------------------->|  Monta como volumen          |
    |                            +----------------------------->|
    |                            |                              |
    |  publisher-config/         |                              |
    +--------------------------->|  apiops-config.js            |
    |                            +----------------------------->|
    |                            |                              |
    |                            |     Usuario accede al        |
    |                            |     Publisher y ve el        |
    |                            |     boton UAT integrado      |
    |                            |                              |
```

---

## Troubleshooting

### Error: "APIOpsConfig is not defined"

El archivo `apiops-config.js` no se esta cargando.

**Solucion**:
1. Verificar que existe en `publisher-config/`
2. Verificar el volumen en docker-compose.yml
3. Verificar que index.jsp lo incluye

### Error: "Cannot read property 'github' of undefined"

El archivo existe pero no tiene la estructura correcta.

**Solucion**:
Verificar que el archivo tiene `window.APIOpsConfig = {...}`

### El boton no aparece

Puede ser:
1. El bundle no esta actualizado (hash viejo en index.jsp)
2. Cache del navegador

**Solucion**:
1. Verificar que el hash en index.jsp coincide con el archivo en publisher-dropin
2. Hard refresh: Ctrl+Shift+R
3. O en DevTools > Network > "Disable cache"

### Error de compilacion "heap out of memory"

La compilacion usa mucha memoria (~4GB).

**Solucion**:
```bash
NODE_OPTIONS=--max_old_space_size=4096 pnpm run build:prod
```

---

## Resumen de archivos

| Archivo | Proposito |
|---------|-----------|
| `UATRegistration.jsx` | Componente React del boton |
| `LifeCycle.jsx` | Donde se importa el componente |
| `index.HASH.bundle.js` | JavaScript compilado |
| `index.jsp` | Pagina que carga los bundles |
| `apiops-config.js` | Configuracion (token, repo, etc) |

---

## Estructura final

```
apim-local-env/
  publisher-dropin/
    index.a1b2c3.bundle.js     <- Bundle compilado
    ...otros archivos...

  publisher-dropin-pages/
    index.jsp                   <- Pagina modificada

  publisher-config/
    apiops-config.js            <- Tu configuracion

  wso2-source/
    apim-apps/                  <- Codigo fuente (git clone)

  wso2-patch/
    source-files/
      UATRegistration.jsx       <- Componente fuente
```

---

## Comandos utiles

```bash
# Ver hash del bundle actual
ls publisher-dropin/index.*.bundle.js

# Ver que hash espera index.jsp
grep "bundle.js" publisher-dropin-pages/index.jsp

# Recompilar todo
./scripts/build-publisher.sh

# Ver logs de WSO2
docker compose logs -f wso2-apim
```

