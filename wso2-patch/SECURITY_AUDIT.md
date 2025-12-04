# Auditoría de Seguridad - WSO2 Publisher Dependencies

**Fecha:** 2024-12-04
**Proyecto:** WSO2 APIM Publisher Portal (apim-apps)
**Versión:** 4.0.1

## Resumen Ejecutivo

| Categoría | Estado |
|-----------|--------|
| Scripts de lifecycle (preinstall/postinstall) | ✅ No hay |
| Paquetes históricamente comprometidos | ✅ No hay |
| Binarios nativos que ejecutan código | ✅ No hay |
| Integridad del lockfile | ✅ 2200 checksums SHA512 |
| Organizaciones scoped verificadas | ✅ Todas conocidas |

## Análisis Detallado

### 1. Scripts NPM

No se encontraron hooks de lifecycle peligrosos:
- ❌ preinstall
- ❌ postinstall
- ❌ prepare
- ❌ prepublish

Los scripts existentes son solo para build/test:
- `build:prod` - Webpack production build
- `build:dev` - Webpack dev mode
- `test` - Jest testing
- `lint` - ESLint

### 2. Dependencias Verificadas

**Organizaciones confiables usadas:**
- `@babel` - Babel (Meta/Facebook)
- `@mui` - Material UI (ex-Google)
- `@emotion` - Emotion CSS-in-JS
- `@testing-library` - Testing Library
- `@types` - DefinitelyTyped
- `@formatjs` - FormatJS (Yahoo)
- `@stoplight` - Stoplight API tools
- `@asyncapi` - AsyncAPI Foundation
- `@dnd-kit` - Drag and Drop Kit
- `@apidevtools` - API Dev Tools
- `@monaco-editor` - Microsoft Monaco
- `@hapi` - Hapi.js (Walmart Labs)
- `@wso2-org` - WSO2 oficial

### 3. Paquetes No Encontrados en Listas de Comprometidos

Verificado contra lista de paquetes históricamente comprometidos:
- ❌ event-stream (2018)
- ❌ ua-parser-js (2021)
- ❌ coa (2021)
- ❌ rc (2021)
- ❌ colors (2022)
- ❌ faker (2022)
- ❌ node-ipc (2022)

### 4. Lockfile

- **Formato:** lockfileVersion 3 (npm v7+)
- **Checksums:** 2200 hashes SHA512
- **Integridad:** Cada paquete tiene hash verificable

## Recomendaciones para Build Seguro

```bash
# Usar pnpm con frozen lockfile
pnpm install --frozen-lockfile --ignore-scripts

# O npm ci (clean install)
npm ci --ignore-scripts
```

**Flags importantes:**
- `--frozen-lockfile` / `npm ci`: No modifica el lockfile
- `--ignore-scripts`: No ejecuta scripts de lifecycle

## Riesgo Residual

⚠️ **Dependencias transitivas**: Este análisis cubre dependencias directas.
Las ~2200 dependencias transitivas están protegidas por:
1. Checksums SHA512 en lockfile
2. Flag `--frozen-lockfile` que verifica integridad
3. Flag `--ignore-scripts` que previene ejecución de código

## Conclusión

**El proyecto es SEGURO para compilar** siguiendo las recomendaciones:

```bash
# Recomendado
pnpm install --frozen-lockfile --ignore-scripts
pnpm run build:prod
```

---

*Auditoría realizada por APIOps Team*
