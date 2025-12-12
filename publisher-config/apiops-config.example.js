// =============================================================================
// APIOps Configuration for Publisher
// =============================================================================
//
// INSTRUCCIONES:
//   1. Copiar: cp apiops-config.example.js apiops-config.js
//   2. Reemplazar 'YOUR_GITHUB_TOKEN_HERE' con tu token real
//   3. Actualizar owner y repo según tu organización
//
// Este archivo se monta en el Publisher y permite configurar el componente
// UATRegistration sin necesidad de recompilar.
//
// =============================================================================

window.APIOpsConfig = {
    // Habilitar logs de debug (false en producción)
    debug: false,

    // Configuración de GitHub para WSO2-Processor
    github: {
        // Personal Access Token de GitHub
        // Crear en: https://github.com/settings/tokens
        // Scopes requeridos: repo
        token: 'YOUR_GITHUB_TOKEN_HERE',

        // Configuración del repositorio WSO2-Processor
        owner: 'tu-organizacion',
        repo: 'WSO2-Processor',
        workflow: 'receive-uat-request.yml',
    },

    // Feature flags para habilitar/deshabilitar funcionalidades
    features: {
        uatRegistration: true,   // Registro en UAT (activo)
        nftPromotion: false,     // Promoción a NFT (futuro)
        proPromotion: false,     // Promoción a PRO (futuro)
    },
};
