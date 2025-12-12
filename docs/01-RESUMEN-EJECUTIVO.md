# Sistema APIOps - Resumen Ejecutivo

**Proyecto**: apim-local-env
**Version**: 1.0 (MVP)
**Fecha**: 2025-12-12

---

## Que es este proyecto

Sistema automatizado para registrar APIs en entornos UAT/NFT/PRO, integrando WSO2 API Manager con GitHub y preparado para ITSM Helix.

**En una frase**: Cuando un desarrollador publica una API, con un clic queda registrada en Git con trazabilidad completa.

---

## Metricas clave

| Metrica | Valor |
|---------|-------|
| Tiempo de registro E2E | 30-45 segundos |
| APIs soportadas | 2,500+ concurrentes |
| Automatizacion | 100% (sin intervencion manual) |
| Entornos | UAT, NFT, PRO |

---

## Arquitectura (Alto nivel)

```
Usuario                    Sistema interno              Repositorios Git
   |                            |                            |
   |  1. Clic "Registrar"       |                            |
   +--------------------------->|                            |
   |                            |  2. Exporta API            |
   |                            |  3. Crea solicitud         |
   |                            |  4. Simula aprobacion      |
   |                            +--------------------------->|
   |                            |  5. Crea PR + merge        |
   |  6. "Registrado OK"        |                            |
   |<---------------------------+                            |
```

---

## Componentes

| Repositorio | Funcion |
|-------------|---------|
| **apim-local-env** | Entorno Docker con WSO2 + configuracion |
| **apim-exporter-wso2** | Exporta APIs desde WSO2 (runner local) |
| **apim-apiops-controller** | Orquesta flujo y gestiona repositorios |
| **apim-domain-*** | Repositorios por area de negocio |

---

## Flujo de trabajo

1. **Desarrollador** publica API en WSO2 Publisher
2. **Clic** en "Registrar en UAT"
3. **Sistema** valida requisitos (publicada, desplegada, subdominio)
4. **GitHub Actions** exporta API y crea solicitud
5. **Helix** (simulado) aprueba automaticamente
6. **PR automatico** se mergea al repositorio del dominio
7. **Desarrollador** ve confirmacion en pantalla

---

## Estructura de datos (Git)

```
apim-domain-rrhh/
  apis/
    EmployeeAPI/
      state.yaml           <- Estado por entorno
      1.0.0/
        api.yaml           <- Definicion API
        Definitions/
          swagger.yaml     <- Contrato OpenAPI
        Conf/
          params.yaml      <- Config UAT/NFT/PRO
          request.yaml     <- Trazabilidad
```

---

## Beneficios

### Para Desarrollo
- Registro automatico sin tickets manuales
- Feedback visual en tiempo real
- Errores claros y accionables

### Para Operaciones
- Trazabilidad completa en Git
- Sin modificar WSO2 (sistema dropin)
- Auditoria via Issues de GitHub

### Para Arquitectura
- Escalable (2,500+ APIs)
- Preparado para ITSM real
- Multi-entorno (UAT/NFT/PRO)

---

## Estado actual

- [x] Componente React en Publisher
- [x] Flujo E2E funcionando
- [x] Estructura multi-entorno
- [x] 18 pruebas E2E pasando
- [ ] Integracion Helix real (simulado)
- [ ] Deployment real a WSO2 por entorno

---

## Proximos pasos

1. Integracion con Helix ITSM real
2. Despliegue automatico a WSO2 NFT/PRO
3. Dashboard de metricas
