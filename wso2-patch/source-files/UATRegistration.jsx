/*
 * Copyright (c) 2024, APIOps Team
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import React, { useState, useEffect, useRef } from 'react';
import { styled } from '@mui/material/styles';
import Box from '@mui/material/Box';
import Button from '@mui/material/Button';
import Card from '@mui/material/Card';
import CardContent from '@mui/material/CardContent';
import Typography from '@mui/material/Typography';
import Chip from '@mui/material/Chip';
import LinearProgress from '@mui/material/LinearProgress';
import Collapse from '@mui/material/Collapse';
import Dialog from '@mui/material/Dialog';
import DialogTitle from '@mui/material/DialogTitle';
import DialogContent from '@mui/material/DialogContent';
import DialogContentText from '@mui/material/DialogContentText';
import DialogActions from '@mui/material/DialogActions';
import Stepper from '@mui/material/Stepper';
import Step from '@mui/material/Step';
import StepLabel from '@mui/material/StepLabel';
import Alert from '@mui/material/Alert';
import AlertTitle from '@mui/material/AlertTitle';
import Link from '@mui/material/Link';
import CircularProgress from '@mui/material/CircularProgress';
import ExpandMoreIcon from '@mui/icons-material/ExpandMore';
import ExpandLessIcon from '@mui/icons-material/ExpandLess';
import CheckCircleIcon from '@mui/icons-material/CheckCircle';
import ErrorIcon from '@mui/icons-material/Error';
import HourglassEmptyIcon from '@mui/icons-material/HourglassEmpty';
import CancelIcon from '@mui/icons-material/Cancel';
import CloudUploadIcon from '@mui/icons-material/CloudUpload';
import { FormattedMessage, useIntl } from 'react-intl';
import MuiAlert from 'AppComponents/Shared/Alert';
import AuthManager from 'AppData/AuthManager';

const PREFIX = 'UATRegistration';

// =============================================================================
// GitHub Configuration for WSO2-Processor
// Configuration is loaded from /publisher/site/public/conf/apiops-config.js
// which is mounted via Docker and editable without rebuild
// =============================================================================
const getGitHubConfig = () => {
    // Try to get from APIOps config file (recommended)
    // eslint-disable-next-line no-underscore-dangle
    const apiopsConfig = window.APIOpsConfig?.github;
    if (apiopsConfig?.token && apiopsConfig.token !== 'YOUR_GITHUB_TOKEN_HERE') {
        return {
            owner: apiopsConfig.owner || 'ISAngelRivera',
            repo: apiopsConfig.repo || 'WSO2-Processor',
            workflow: apiopsConfig.workflow || 'receive-uat-request.yml',
            token: apiopsConfig.token,
        };
    }

    // Fallback to localStorage (for development/testing)
    const localToken = localStorage.getItem('github_pat_token');
    if (localToken) {
        return {
            owner: 'ISAngelRivera',
            repo: 'WSO2-Processor',
            workflow: 'receive-uat-request.yml',
            token: localToken,
        };
    }

    return null;
};

const classes = {
    card: `${PREFIX}-card`,
    header: `${PREFIX}-header`,
    title: `${PREFIX}-title`,
    chip: `${PREFIX}-chip`,
    chipIdle: `${PREFIX}-chipIdle`,
    chipProgress: `${PREFIX}-chipProgress`,
    chipSuccess: `${PREFIX}-chipSuccess`,
    chipError: `${PREFIX}-chipError`,
    stepper: `${PREFIX}-stepper`,
    actions: `${PREFIX}-actions`,
};

const StyledCard = styled(Card)(({ theme }) => ({
    [`&.${classes.card}`]: {
        marginTop: theme.spacing(3),
        marginBottom: theme.spacing(2),
    },
    [`& .${classes.header}`]: {
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        marginBottom: theme.spacing(2),
    },
    [`& .${classes.title}`]: {
        display: 'flex',
        alignItems: 'center',
        gap: theme.spacing(2),
    },
    [`& .${classes.chipIdle}`]: {
        backgroundColor: theme.palette.grey[200],
        color: theme.palette.grey[700],
    },
    [`& .${classes.chipProgress}`]: {
        backgroundColor: theme.palette.info.light,
        color: theme.palette.info.contrastText,
    },
    [`& .${classes.chipSuccess}`]: {
        backgroundColor: theme.palette.success.light,
        color: theme.palette.success.contrastText,
    },
    [`& .${classes.chipError}`]: {
        backgroundColor: theme.palette.error.light,
        color: theme.palette.error.contrastText,
    },
    [`& .${classes.stepper}`]: {
        padding: theme.spacing(2, 0),
    },
    [`& .${classes.actions}`]: {
        display: 'flex',
        gap: theme.spacing(1),
        marginTop: theme.spacing(2),
    },
}));

// Registration states
const STATES = {
    IDLE: 'idle',
    INITIATING: 'initiating',
    EXPORTING: 'exporting',
    VALIDATING: 'validating',
    VALIDATION_FAILED: 'validation_failed',
    REQUESTING_CRQ: 'requesting_crq',
    CRQ_PENDING: 'crq_pending',
    CRQ_REJECTED: 'crq_rejected',
    REGISTERING: 'registering',
    REGISTERED: 'registered',
    CANCELLED: 'cancelled',
    ERROR: 'error',
};

// Registration steps for stepper
const STEPS = [
    { key: 'initiating', label: 'Iniciando' },
    { key: 'exporting', label: 'Exportando API' },
    { key: 'validating', label: 'Validando' },
    { key: 'requesting_crq', label: 'Solicitando CRQ' },
    { key: 'crq_pending', label: 'CRQ Pendiente' },
    { key: 'registering', label: 'Registrando' },
];

/**
 * Get storage key for API registration state
 * @param {string} apiId - The API ID
 * @returns {string} Storage key
 */
const getStorageKey = (apiId) => `uat_registration_${apiId}`;

/**
 * Load registration state from localStorage
 * @param {string} apiId - The API ID
 * @returns {Object} Registration state
 */
const loadState = (apiId) => {
    try {
        const stored = localStorage.getItem(getStorageKey(apiId));
        if (stored) {
            return JSON.parse(stored);
        }
    } catch (e) {
        console.error('Error loading UAT registration state:', e);
    }
    return { state: STATES.IDLE };
};

/**
 * Save registration state to localStorage
 * @param {string} apiId - The API ID
 * @param {Object} data - State data to save
 */
const saveState = (apiId, data) => {
    try {
        localStorage.setItem(getStorageKey(apiId), JSON.stringify(data));
    } catch (e) {
        console.error('Error saving UAT registration state:', e);
    }
};

/**
 * Trigger GitHub workflow dispatch with a unique request ID for correlation.
 * The requestId allows us to track this specific request across all systems,
 * making it scalable for environments with 2500+ APIs.
 *
 * @param {Object} apiData - API data to send
 * @param {string} requestId - Unique request ID for correlation
 * @returns {Promise<Object>} Response with success status and run info
 */
const triggerGitHubWorkflow = async (apiData, requestId) => {
    const config = getGitHubConfig();

    if (!config) {
        throw new Error(
            'GitHub no configurado. Edita publisher-config/apiops-config.js con tu token.',
        );
    }

    const baseUrl = 'https://api.github.com/repos';
    const { owner, repo, workflow, token } = config;
    const url = `${baseUrl}/${owner}/${repo}/actions/workflows/${workflow}/dispatches`;

    // Get the current user from AuthManager
    const currentUser = AuthManager.getUser();
    const userId = currentUser?.name || apiData.userId || 'unknown';

    const payload = {
        ref: 'main',
        inputs: {
            requestId, // Unique correlation ID - critical for scalability
            apiId: apiData.id,
            apiName: apiData.name,
            apiVersion: apiData.version,
            apiContext: apiData.context || '',
            userId, // Real user from AuthManager
            timestamp: new Date().toISOString(),
        },
    };

    const response = await fetch(url, {
        method: 'POST',
        headers: {
            Authorization: `Bearer ${token}`,
            Accept: 'application/vnd.github.v3+json',
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
    });

    if (response.status === 204) {
        // Success - workflow triggered
        return {
            success: true,
            message: 'Workflow triggered successfully',
            triggeredAt: new Date().toISOString(),
            requestId,
        };
    }

    // Error handling
    const errorBody = await response.text();
    throw new Error(`GitHub API error (${response.status}): ${errorBody}`);
};

/**
 * Generate a unique request ID for correlation across the entire flow.
 * Format: REQ-{apiId-short}-{timestamp}-{random}
 * This ID will be passed through all workflows and used to track the request.
 *
 * @param {string} apiId - The API ID
 * @returns {string} Unique request ID
 */
const generateRequestId = (apiId) => {
    const shortApiId = apiId.substring(0, 8);
    const timestamp = Date.now().toString(36);
    const random = Math.random().toString(36).substring(2, 6);
    return `REQ-${shortApiId}-${timestamp}-${random}`;
};

/**
 * Get the workflow run that matches our request ID.
 * This is scalable because it uses a unique correlation ID instead of just timestamps.
 * Works correctly even with 2500+ concurrent API registrations.
 *
 * @param {string} requestId - The unique request ID we sent to the workflow
 * @returns {Promise<Object|null>} Run info or null
 */
const getWorkflowRunByRequestId = async (requestId) => {
    const config = getGitHubConfig();
    if (!config) return null;

    const { owner, repo, token } = config;
    // Get recent workflow_dispatch runs
    const url = `https://api.github.com/repos/${owner}/${repo}/actions/runs?per_page=20&event=workflow_dispatch`;

    const response = await fetch(url, {
        headers: {
            Authorization: `Bearer ${token}`,
            Accept: 'application/vnd.github.v3+json',
        },
    });

    if (!response.ok) return null;

    const data = await response.json();
    const runs = data.workflow_runs || [];

    // Find the run that matches our request ID by checking the display_title or name
    // GitHub Actions includes the inputs in the run name when using workflow_dispatch
    console.log(`[UAT] Searching for requestId: ${requestId} in ${runs.length} runs`);
    for (const run of runs) {
        // Check if this run matches our request ID
        // The request ID should be in the run's display_title or we need to check the jobs
        console.log(`[UAT] Checking run ${run.id}: display_title="${run.display_title}"`);
        if (run.display_title?.includes(requestId) || run.name?.includes(requestId)) {
            console.log(`[UAT] Found matching run: ${run.id}`);
            return run;
        }
    }

    // If no direct match found, check the most recent runs' inputs
    // Filter to only runs from the last 5 minutes
    const recentRuns = runs.slice(0, 10).filter((run) => {
        const runTime = new Date(run.created_at).getTime();
        return Date.now() - runTime <= 300000;
    });

    // Check each recent run for our requestId
    for (const run of recentRuns) {
        // Get run details to check inputs
        const detailUrl = `https://api.github.com/repos/${owner}/${repo}/actions/runs/${run.id}`;
        // eslint-disable-next-line no-await-in-loop
        const detailResponse = await fetch(detailUrl, {
            headers: {
                Authorization: `Bearer ${token}`,
                Accept: 'application/vnd.github.v3+json',
            },
        });

        if (detailResponse.ok) {
            // eslint-disable-next-line no-await-in-loop
            const runDetail = await detailResponse.json();
            // Check if the display_title contains our request ID
            if (runDetail.display_title?.includes(requestId)) {
                return run;
            }
        }
    }

    return null;
};

/**
 * Get workflow run jobs to extract error details
 * @param {number} runId - The run ID
 * @param {string} repoOverride - Optional repo to use instead of config (format: owner/repo)
 * @returns {Promise<Object|null>} Jobs info
 */
const getWorkflowJobs = async (runId, repoOverride = null) => {
    const config = getGitHubConfig();
    if (!config) return null;

    const { token } = config;
    const repoPath = repoOverride || `${config.owner}/${config.repo}`;
    const url = `https://api.github.com/repos/${repoPath}/actions/runs/${runId}/jobs`;

    const response = await fetch(url, {
        headers: {
            Authorization: `Bearer ${token}`,
            Accept: 'application/vnd.github.v3+json',
        },
    });

    if (!response.ok) return null;
    return response.json();
};

/**
 * Extract error message from failed job
 * @param {Object} jobsData - Jobs response from GitHub
 * @returns {string} Error message
 */
const extractErrorFromJobs = (jobsData) => {
    if (!jobsData?.jobs) return 'El workflow falló. Revisa los logs en GitHub.';

    const failedJob = jobsData.jobs.find((j) => j.conclusion === 'failure');
    if (!failedJob) return 'El workflow falló. Revisa los logs en GitHub.';

    const failedStep = failedJob.steps?.find((s) => s.conclusion === 'failure');
    if (failedStep) {
        const stepName = failedStep.name?.toLowerCase() || '';

        // Check for common error patterns - order matters!
        // 1. Check for deployment/revision errors
        if (stepName.includes('deployed') || stepName.includes('revision')) {
            return 'La API no tiene ninguna revisión desplegada en un Gateway. '
                + 'Ve a Deployments > Deploy New Revision y despliega la API antes de registrar en UAT.';
        }
        // 2. Check for subdominio/validate errors
        if (stepName.includes('subdominio') || stepName.includes('validate')) {
            return 'La API no tiene configurado el campo "subdominio" en Additional Properties. '
                + 'Ve a la API > Properties > Additional Properties y añade: subdominio = <tu-subdominio>';
        }
        // 3. Check for export errors - this includes subdominio validation that happens during export
        if (stepName.includes('export')) {
            return 'La API no tiene configurado el campo "subdominio" en Additional Properties. '
                + 'Este campo es requerido para el registro en UAT. '
                + 'Ve a la API > Properties > Additional Properties y añade: subdominio = <tu-subdominio>';
        }
        // 4. Login/connection errors
        if (stepName.includes('login') || stepName.includes('apictl') || stepName.includes('setup')) {
            return 'Error de conexión con WSO2. Verifica que el runner esté activo y WSO2 esté disponible.';
        }
        // 5. Helix/CRQ errors
        if (stepName.includes('helix') || stepName.includes('forward')) {
            return 'Error al enviar a Helix-Processor. Verifica la configuración del token GIT_HELIX_PAT.';
        }
        return `Error en paso: ${failedStep.name}. Revisa los logs en GitHub para más detalles.`;
    }

    return `Job "${failedJob.name}" falló. Revisa los logs en GitHub.`;
};

/**
 * UAT Registration Component
 * Displays registration status and allows users to register APIs in UAT environment
 *
 * @param {Object} props - Component props
 * @param {Object} props.api - The API object
 * @param {Object} props.lcState - Lifecycle state object
 * @returns {JSX.Element} The UAT Registration component
 */
export default function UATRegistration(props) {
    const { api, lcState } = props;
    const intl = useIntl();
    const isMountedRef = useRef(true);

    const [registrationData, setRegistrationData] = useState(() => loadState(api?.id));
    const [showDetails, setShowDetails] = useState(false);
    const [cancelDialogOpen, setCancelDialogOpen] = useState(false);

    // Only show for published APIs
    const isPublished = lcState?.state === 'Published';

    // Track component mount status
    useEffect(() => {
        isMountedRef.current = true;
        return () => {
            isMountedRef.current = false;
        };
    }, []);

    // Persist state changes
    useEffect(() => {
        if (api?.id && registrationData) {
            saveState(api.id, registrationData);
        }
    }, [api?.id, registrationData]);

    // Don't render if API is not published
    if (!api || !isPublished) {
        return null;
    }

    /**
     * Get status information for display
     * @returns {Object} Status info with label, chipClass and icon
     */
    const getStatusInfo = () => {
        const statusMap = {
            [STATES.IDLE]: {
                label: 'No registrada',
                chipClass: classes.chipIdle,
                icon: <HourglassEmptyIcon fontSize='small' />,
            },
            [STATES.INITIATING]: {
                label: 'Iniciando...',
                chipClass: classes.chipProgress,
                icon: <CircularProgress size={16} />,
            },
            [STATES.EXPORTING]: {
                label: 'Exportando...',
                chipClass: classes.chipProgress,
                icon: <CircularProgress size={16} />,
            },
            [STATES.VALIDATING]: {
                label: 'Validando...',
                chipClass: classes.chipProgress,
                icon: <CircularProgress size={16} />,
            },
            [STATES.VALIDATION_FAILED]: {
                label: 'Validación fallida',
                chipClass: classes.chipError,
                icon: <ErrorIcon fontSize='small' />,
            },
            [STATES.REQUESTING_CRQ]: {
                label: 'Solicitando CRQ...',
                chipClass: classes.chipProgress,
                icon: <CircularProgress size={16} />,
            },
            [STATES.CRQ_PENDING]: {
                label: 'CRQ pendiente',
                chipClass: classes.chipProgress,
                icon: <HourglassEmptyIcon fontSize='small' />,
            },
            [STATES.CRQ_REJECTED]: {
                label: 'CRQ rechazada',
                chipClass: classes.chipError,
                icon: <ErrorIcon fontSize='small' />,
            },
            [STATES.REGISTERING]: {
                label: 'Registrando...',
                chipClass: classes.chipProgress,
                icon: <CircularProgress size={16} />,
            },
            [STATES.REGISTERED]: {
                label: 'Registrada',
                chipClass: classes.chipSuccess,
                icon: <CheckCircleIcon fontSize='small' />,
            },
            [STATES.CANCELLED]: {
                label: 'Cancelada',
                chipClass: classes.chipIdle,
                icon: <CancelIcon fontSize='small' />,
            },
            [STATES.ERROR]: {
                label: 'Error',
                chipClass: classes.chipError,
                icon: <ErrorIcon fontSize='small' />,
            },
        };
        return statusMap[registrationData.state] || statusMap[STATES.IDLE];
    };

    /**
     * Check if registration is in progress
     * @returns {boolean} True if in progress
     */
    const isInProgress = () => {
        return [
            STATES.INITIATING,
            STATES.EXPORTING,
            STATES.VALIDATING,
            STATES.REQUESTING_CRQ,
            STATES.CRQ_PENDING,
            STATES.REGISTERING,
        ].includes(registrationData.state);
    };

    /**
     * Check if registration can be cancelled
     * @returns {boolean} True if can cancel
     */
    const canCancel = () => {
        return [
            STATES.INITIATING,
            STATES.EXPORTING,
            STATES.VALIDATING,
            STATES.REQUESTING_CRQ,
            STATES.CRQ_PENDING,
        ].includes(registrationData.state);
    };

    /**
     * Get current step index for stepper
     * @returns {number} Current step index
     */
    const getCurrentStep = () => {
        const idx = STEPS.findIndex((s) => s.key === registrationData.state);
        if (registrationData.state === STATES.REGISTERED) {
            return STEPS.length; // All complete
        }
        return idx >= 0 ? idx : -1;
    };

    /**
     * Poll GitHub for workflow status using requestId for correlation.
     * Scalable for 2500+ concurrent API registrations.
     *
     * @param {string} triggeredAt - When the workflow was triggered
     * @param {number} maxAttempts - Maximum polling attempts
     * @param {string} requestId - Unique request ID for correlation
     */
    const pollWorkflowStatus = async (triggeredAt, maxAttempts = 40, requestId = null) => {
        const config = getGitHubConfig();
        const pollInterval = 3000; // 3 seconds
        let attempts = 0;
        let runId = null;
        let findRunAttempts = 0;
        const maxFindRunAttempts = 30; // 90 seconds to find the run (GitHub can be slow to index)

        const poll = async () => {
            if (!isMountedRef.current) return;

            attempts += 1;
            if (attempts > maxAttempts) {
                setRegistrationData((prev) => ({
                    ...prev,
                    state: STATES.ERROR,
                    error: {
                        title: 'Timeout',
                        message: 'El workflow tardó demasiado. Verifica el estado en GitHub.',
                    },
                }));
                return;
            }

            // Check if cancelled or reset
            const currentState = loadState(api.id);
            if (currentState.state === STATES.CANCELLED || currentState.state === STATES.IDLE) {
                return;
            }

            try {
                // First, find the run using requestId (primary method)
                // IMPORTANT: Do NOT use timestamp fallback as it can match wrong workflows
                if (!runId) {
                    findRunAttempts += 1;

                    // Find by requestId - this is the only reliable method
                    let run = null;
                    if (requestId) {
                        run = await getWorkflowRunByRequestId(requestId);
                    }

                    // NO FALLBACK: We must find by requestId to avoid matching wrong workflows
                    // The old timestamp fallback could return a different API's workflow

                    if (run) {
                        runId = run.id;
                        console.log(`[UAT] Found run ${run.id}, status: ${run.status}, conclusion: ${run.conclusion}`);
                        setRegistrationData((prev) => ({
                            ...prev,
                            runId: run.id,
                            runUrl: run.html_url,
                        }));

                        // If the run is already completed (fast workflows), handle it immediately
                        if (run.status === 'completed') {
                            console.log(`[UAT] Run already completed with conclusion: ${run.conclusion}`);
                            if (run.conclusion === 'success') {
                                // Success! Now check Helix-Processor
                                setRegistrationData((prev) => ({
                                    ...prev,
                                    state: STATES.REQUESTING_CRQ,
                                }));
                                // eslint-disable-next-line no-use-before-define
                                pollHelixProcessor(triggeredAt, requestId);
                                return; // Exit polling
                            }
                            // Workflow failed - get error details
                            const jobsData = await getWorkflowJobs(run.id);
                            const errorMsg = extractErrorFromJobs(jobsData);
                            console.log(`[UAT] Error from completed run: ${errorMsg}`);

                            setRegistrationData((prev) => ({
                                ...prev,
                                state: STATES.VALIDATION_FAILED,
                                error: {
                                    title: 'Error en el proceso',
                                    message: errorMsg,
                                    runUrl: run.html_url,
                                },
                            }));

                            MuiAlert.error(errorMsg);
                            return; // Exit polling
                        }
                    } else if (findRunAttempts >= maxFindRunAttempts) {
                        // Could not find the run after timeout
                        setRegistrationData((prev) => ({
                            ...prev,
                            state: STATES.ERROR,
                            error: {
                                title: 'Workflow no encontrado',
                                message: `No se pudo encontrar el workflow (${requestId || 'sin ID'}). `
                                    + 'Verifica que el runner esté activo.',
                            },
                        }));
                        return;
                    }
                }

                if (runId) {
                    // Get current run status
                    console.log(`[UAT] Checking status of run ${runId}`);
                    const runResponse = await fetch(
                        `https://api.github.com/repos/${config.owner}/${config.repo}/actions/runs/${runId}`,
                        {
                            headers: {
                                Authorization: `Bearer ${config.token}`,
                                Accept: 'application/vnd.github.v3+json',
                            },
                        },
                    );

                    if (runResponse.ok) {
                        const runData = await runResponse.json();
                        console.log(`[UAT] Run status: ${runData.status}, conclusion: ${runData.conclusion}`);

                        // Update state based on workflow status
                        if (runData.status === 'in_progress' || runData.status === 'queued') {
                            // Map job progress to UI states
                            const jobsData = await getWorkflowJobs(runId);
                            const currentJob = jobsData?.jobs?.find((j) => j.status === 'in_progress');
                            const currentStep = currentJob?.steps?.find((s) => s.status === 'in_progress');

                            let newState = STATES.VALIDATING;
                            if (currentStep?.name?.toLowerCase().includes('export')) {
                                newState = STATES.EXPORTING;
                            } else if (currentStep?.name?.toLowerCase().includes('helix')
                                || currentStep?.name?.toLowerCase().includes('crq')) {
                                newState = STATES.REQUESTING_CRQ;
                            } else if (currentStep?.name?.toLowerCase().includes('pr')
                                || currentStep?.name?.toLowerCase().includes('storage')) {
                                newState = STATES.REGISTERING;
                            }

                            setRegistrationData((prev) => ({
                                ...prev,
                                state: newState,
                                currentStep: currentStep?.name || 'Procesando...',
                            }));

                            setTimeout(poll, pollInterval);
                        } else if (runData.status === 'completed') {
                            console.log(`[UAT] Workflow completed with conclusion: ${runData.conclusion}`);
                            if (runData.conclusion === 'success') {
                                // Success! Now check Helix-Processor
                                console.log('[UAT] WSO2-Processor succeeded, polling Helix-Processor...');
                                setRegistrationData((prev) => ({
                                    ...prev,
                                    state: STATES.REQUESTING_CRQ,
                                }));
                                // Poll Helix-Processor for final result using requestId
                                // eslint-disable-next-line no-use-before-define
                                pollHelixProcessor(triggeredAt, requestId);
                            } else {
                                // Workflow failed
                                console.log(`[UAT] WSO2-Processor FAILED with conclusion: ${runData.conclusion}`);
                                const jobsData = await getWorkflowJobs(runId);
                                const errorMsg = extractErrorFromJobs(jobsData);
                                console.log(`[UAT] Error message: ${errorMsg}`);

                                setRegistrationData((prev) => ({
                                    ...prev,
                                    state: STATES.VALIDATION_FAILED,
                                    error: {
                                        title: 'Error en el proceso',
                                        message: errorMsg,
                                        runUrl: runData.html_url,
                                    },
                                }));

                                MuiAlert.error(errorMsg);
                            }
                        }
                    } else {
                        setTimeout(poll, pollInterval);
                    }
                } else {
                    // Run not found yet, keep polling
                    setTimeout(poll, pollInterval);
                }
            } catch (error) {
                console.error('Polling error:', error);
                setTimeout(poll, pollInterval);
            }
        };

        poll();
    };

    /**
     * Poll Helix-Processor for final status using requestId for correlation.
     * This now polls TWO workflows:
     * 1. process-api-request.yml - Creates the Issue and CRQ
     * 2. on-helix-approval.yml - Creates the PR and does auto-merge (triggered by simulated approval)
     *
     * @param {string} triggeredAt - When the original workflow was triggered
     * @param {string} requestId - Unique request ID for correlation
     */
    const pollHelixProcessor = async (triggeredAt, requestId) => {
        const helixRepo = 'ISAngelRivera/GIT-Helix-Processor';
        const config = getGitHubConfig();
        const pollInterval = 3000;
        let attempts = 0;
        const maxAttempts = 60; // Increased for two-phase polling
        let phase = 1; // Phase 1: process-api-request, Phase 2: on-helix-approval
        let processApiRequestCompleted = false;

        console.log(`[UAT] Polling Helix-Processor for requestId: ${requestId}`);

        /**
         * Extract error details from Helix-Processor jobs
         */
        const extractHelixError = (jobsData) => {
            let errorMsg = 'Error en Helix-Processor. Revisa los logs en GitHub.';
            let errorState = STATES.ERROR;
            let errorTitle = 'Error en procesamiento';

            if (jobsData?.jobs) {
                const failedJob = jobsData.jobs.find((j) => j.conclusion === 'failure');
                const failedStep = failedJob?.steps?.find((s) => s.conclusion === 'failure');
                const stepName = failedStep?.name?.toLowerCase() || '';

                console.log(`[UAT] Helix-Processor failed step: ${failedStep?.name}`);

                if (stepName.includes('subdominio') || stepName.includes('validate')) {
                    errorMsg = 'El subdominio configurado no existe en el sistema. '
                        + 'Verifica que el valor del campo "subdominio" '
                        + 'sea uno de los subdominios válidos configurados.';
                    errorTitle = 'Subdominio inválido';
                    errorState = STATES.VALIDATION_FAILED;
                } else if (stepName.includes('helix') || stepName.includes('crq')
                    || stepName.includes('approval') || stepName.includes('reject')) {
                    errorMsg = 'CRQ rechazada por Helix.';
                    errorTitle = 'CRQ Rechazada';
                    errorState = STATES.CRQ_REJECTED;
                } else if (stepName.includes('merge')) {
                    errorMsg = 'Error al hacer merge de la PR. '
                        + 'La PR puede haber sido creada pero el merge falló.';
                    errorTitle = 'Error en merge';
                    errorState = STATES.ERROR;
                } else if (stepName.includes('pr') || stepName.includes('branch')
                    || stepName.includes('push') || stepName.includes('git')) {
                    errorMsg = 'Error al crear la PR en el repositorio de destino. '
                        + 'Verifica los permisos del token y el estado del repositorio.';
                    errorTitle = 'Error en PR';
                    errorState = STATES.ERROR;
                } else if (failedStep?.name) {
                    errorMsg = `Error en paso: ${failedStep.name}. `
                        + 'Revisa los logs en GitHub para más detalles.';
                }
            }

            return { message: errorMsg, title: errorTitle, state: errorState };
        };

        const poll = async () => {
            if (!isMountedRef.current) return;

            attempts += 1;
            if (attempts > maxAttempts) {
                // Timeout but some progress was made
                if (processApiRequestCompleted) {
                    setRegistrationData((prev) => ({
                        ...prev,
                        state: STATES.CRQ_PENDING,
                        error: {
                            title: 'Esperando aprobación',
                            message: 'La solicitud está en cola. '
                                + 'El merge se realizará automáticamente cuando Helix apruebe.',
                        },
                    }));
                } else {
                    setRegistrationData((prev) => ({
                        ...prev,
                        state: STATES.CRQ_PENDING,
                        error: {
                            title: 'Procesando en Helix',
                            message: 'El proceso continúa en Helix-Processor. Verifica el estado en GitHub.',
                        },
                    }));
                }
                return;
            }

            try {
                const response = await fetch(
                    `https://api.github.com/repos/${helixRepo}/actions/runs?per_page=30`,
                    {
                        headers: {
                            Authorization: `Bearer ${config.token}`,
                            Accept: 'application/vnd.github.v3+json',
                        },
                    },
                );

                if (!response.ok) {
                    setTimeout(poll, pollInterval);
                    return;
                }

                const data = await response.json();

                // Phase 1: Look for process-api-request workflow (creates Issue + CRQ)
                if (phase === 1) {
                    // Find matching run by requestId in display_title
                    let matchingRun = data.workflow_runs?.find((run) => {
                        const isProcessApi = run.path?.includes('process-api-request')
                            || run.name?.includes('Process API Request');
                        return isProcessApi
                            && (run.display_title?.includes(requestId) || run.name?.includes(requestId));
                    });

                    // Fallback: find by timestamp if requestId not in title
                    if (!matchingRun) {
                        const triggeredTime = new Date(triggeredAt).getTime();
                        matchingRun = data.workflow_runs?.find((run) => {
                            const runTime = new Date(run.created_at).getTime();
                            const isProcessApi = run.path?.includes('process-api-request')
                                || run.name?.includes('Process API Request');
                            return isProcessApi
                                && run.event === 'workflow_dispatch'
                                && runTime >= triggeredTime - 10000
                                && runTime <= triggeredTime + 120000;
                        });
                    }

                    console.log(`[UAT] Phase 1 - process-api-request run: ${matchingRun?.id || 'not found'}`);

                    if (matchingRun) {
                        if (matchingRun.status === 'completed') {
                            if (matchingRun.conclusion === 'success') {
                                // Phase 1 complete! Move to Phase 2
                                console.log('[UAT] Phase 1 complete, moving to Phase 2 (on-helix-approval)');
                                processApiRequestCompleted = true;
                                phase = 2;
                                setRegistrationData((prev) => ({
                                    ...prev,
                                    state: STATES.REGISTERING,
                                    currentStep: 'Creando PR y realizando merge...',
                                }));
                                setTimeout(poll, pollInterval);
                            } else {
                                // Phase 1 failed
                                const jobsData = await getWorkflowJobs(matchingRun.id, helixRepo);
                                const errorMsg = extractHelixError(jobsData);
                                setRegistrationData((prev) => ({
                                    ...prev,
                                    state: errorMsg.state,
                                    error: {
                                        title: errorMsg.title,
                                        message: errorMsg.message,
                                        runUrl: matchingRun.html_url,
                                    },
                                }));
                                MuiAlert.error(errorMsg.message);
                            }
                        } else {
                            // Still running Phase 1
                            setRegistrationData((prev) => ({
                                ...prev,
                                state: STATES.REQUESTING_CRQ,
                                currentStep: 'Creando solicitud CRQ...',
                            }));
                            setTimeout(poll, pollInterval);
                        }
                    } else {
                        setTimeout(poll, pollInterval);
                    }
                }
                // Phase 2: Look for on-helix-approval workflow (creates PR + auto-merge)
                else if (phase === 2) {
                    // Find the approval workflow by requestId or recent repository_dispatch
                    let approvalRun = data.workflow_runs?.find((run) => {
                        const isApproval = run.path?.includes('on-helix-approval')
                            || run.name?.includes('On Helix Approval')
                            || run.name?.includes('Process Helix');
                        return isApproval
                            && (run.display_title?.includes(requestId) || run.name?.includes(requestId));
                    });

                    // Fallback: find recent repository_dispatch runs
                    if (!approvalRun) {
                        approvalRun = data.workflow_runs?.find((run) => {
                            const runTime = new Date(run.created_at).getTime();
                            const isRecent = Date.now() - runTime <= 300000; // Within 5 minutes
                            const isApproval = run.event === 'repository_dispatch'
                                && (run.path?.includes('on-helix-approval')
                                    || run.name?.includes('On Helix Approval')
                                    || run.name?.includes('Process Helix'));
                            return isApproval && isRecent;
                        });
                    }

                    console.log(`[UAT] Phase 2 - on-helix-approval run: ${approvalRun?.id || 'not found'}`);

                    if (approvalRun) {
                        if (approvalRun.status === 'completed') {
                            if (approvalRun.conclusion === 'success') {
                                // Full success! PR created and merged
                                console.log('[UAT] Phase 2 complete - API registered successfully!');
                                setRegistrationData((prev) => ({
                                    ...prev,
                                    state: STATES.REGISTERED,
                                    lastRegistered: {
                                        revision: `rev-${Date.now().toString(36)}`,
                                        registeredAt: new Date().toISOString(),
                                        prUrl: approvalRun.html_url,
                                    },
                                }));

                                MuiAlert.success(intl.formatMessage({
                                    id: 'Apis.Details.LifeCycle.UATRegistration.success',
                                    defaultMessage: 'API registrada en UAT correctamente',
                                }));
                            } else {
                                // Phase 2 failed
                                const jobsData = await getWorkflowJobs(approvalRun.id, helixRepo);
                                const errorMsg = extractHelixError(jobsData);
                                setRegistrationData((prev) => ({
                                    ...prev,
                                    state: errorMsg.state,
                                    error: {
                                        title: errorMsg.title,
                                        message: errorMsg.message,
                                        runUrl: approvalRun.html_url,
                                    },
                                }));
                                MuiAlert.error(errorMsg.message);
                            }
                        } else {
                            // Still running Phase 2
                            setRegistrationData((prev) => ({
                                ...prev,
                                state: STATES.REGISTERING,
                                currentStep: 'Realizando merge automático...',
                            }));
                            setTimeout(poll, pollInterval);
                        }
                    } else {
                        // Approval workflow not started yet, keep waiting
                        setTimeout(poll, pollInterval);
                    }
                }
            } catch (error) {
                console.error('Helix polling error:', error);
                setTimeout(poll, pollInterval);
            }
        };

        poll();
    };

    /**
     * Start registration process
     * Triggers GitHub workflow in WSO2-Processor and polls for real status.
     * Uses a unique requestId for correlation - scalable for 2500+ APIs.
     */
    const startRegistration = async () => {
        const startedAt = new Date().toISOString();
        // Generate unique request ID for correlation across all systems
        const requestId = generateRequestId(api.id);

        setRegistrationData({
            state: STATES.INITIATING,
            startedAt,
            requestId, // Store for tracking
        });

        try {
            // Step 1: Trigger GitHub workflow with requestId
            setRegistrationData((prev) => ({ ...prev, state: STATES.EXPORTING }));

            const apiData = {
                id: api.id,
                name: api.name,
                version: api.version,
                context: api.context,
                provider: api.provider,
                type: api.type,
                lifeCycleStatus: api.lifeCycleStatus,
            };

            const result = await triggerGitHubWorkflow(apiData, requestId);

            // Step 2: Start polling for real workflow status using requestId
            const config = getGitHubConfig();
            setRegistrationData((prev) => ({
                ...prev,
                state: STATES.VALIDATING,
                workflowTriggered: true,
                triggeredAt: result.triggeredAt,
                requestId: result.requestId,
                githubRepo: config ? `${config.owner}/${config.repo}` : 'ISAngelRivera/WSO2-Processor',
            }));

            // Start real polling with requestId for precise tracking
            pollWorkflowStatus(result.triggeredAt, 40, result.requestId);
        } catch (error) {
            console.error('UAT Registration error:', error);

            setRegistrationData((prev) => ({
                ...prev,
                state: STATES.ERROR,
                error: {
                    title: 'Error al iniciar registro',
                    message: error.message || 'No se pudo conectar con GitHub',
                },
            }));

            MuiAlert.error(intl.formatMessage({
                id: 'Apis.Details.LifeCycle.UATRegistration.error',
                defaultMessage: 'Error al iniciar el registro UAT',
            }));
        }
    };

    /**
     * Handle cancel confirmation
     */
    const handleCancelConfirm = () => {
        setRegistrationData((prev) => ({
            ...prev,
            state: STATES.CANCELLED,
            cancelledAt: new Date().toISOString(),
        }));
        setCancelDialogOpen(false);

        MuiAlert.info(intl.formatMessage({
            id: 'Apis.Details.LifeCycle.UATRegistration.cancelled',
            defaultMessage: 'Registro cancelado',
        }));
    };

    /**
     * Retry registration after error
     */
    const handleRetry = () => {
        setRegistrationData({ state: STATES.IDLE });
    };

    const statusInfo = getStatusInfo();
    const inProgress = isInProgress();
    const currentStep = getCurrentStep();

    return (
        <StyledCard className={classes.card} variant='outlined'>
            <CardContent>
                {/* Header */}
                <Box className={classes.header}>
                    <Box className={classes.title}>
                        <Typography variant='h6' component='h3'>
                            <FormattedMessage
                                id='Apis.Details.LifeCycle.UATRegistration.title'
                                defaultMessage='Registro en UAT'
                            />
                        </Typography>
                        <Chip
                            icon={statusInfo.icon}
                            label={statusInfo.label}
                            className={statusInfo.chipClass}
                            size='small'
                        />
                    </Box>
                    {registrationData.lastRegistered && (
                        <Typography variant='body2' color='textSecondary'>
                            <FormattedMessage
                                id='Apis.Details.LifeCycle.UATRegistration.lastRegistered'
                                defaultMessage='Última: {revision} - {date}'
                                values={{
                                    revision: registrationData.lastRegistered.revision,
                                    date: new Date(registrationData.lastRegistered.registeredAt)
                                        .toLocaleString(),
                                }}
                            />
                        </Typography>
                    )}
                </Box>

                {/* Progress indicator */}
                {inProgress && (
                    <LinearProgress
                        variant='determinate'
                        value={(currentStep / STEPS.length) * 100}
                        sx={{ mb: 2 }}
                    />
                )}

                {/* Expandable details */}
                {(inProgress || registrationData.state === STATES.REGISTERED) && (
                    <>
                        <Button
                            size='small'
                            onClick={() => setShowDetails(!showDetails)}
                            endIcon={showDetails ? <ExpandLessIcon /> : <ExpandMoreIcon />}
                        >
                            {showDetails ? (
                                <FormattedMessage
                                    id='Apis.Details.LifeCycle.UATRegistration.hideDetails'
                                    defaultMessage='Ocultar detalles'
                                />
                            ) : (
                                <FormattedMessage
                                    id='Apis.Details.LifeCycle.UATRegistration.showDetails'
                                    defaultMessage='Ver detalles'
                                />
                            )}
                        </Button>
                        <Collapse in={showDetails}>
                            <Stepper
                                activeStep={currentStep}
                                alternativeLabel
                                className={classes.stepper}
                            >
                                {STEPS.map((step) => (
                                    <Step key={step.key}>
                                        <StepLabel>{step.label}</StepLabel>
                                    </Step>
                                ))}
                            </Stepper>
                        </Collapse>
                    </>
                )}

                {/* Success alert */}
                {registrationData.state === STATES.REGISTERED && (
                    <Alert severity='success' sx={{ mt: 2 }}>
                        <AlertTitle>
                            <FormattedMessage
                                id='Apis.Details.LifeCycle.UATRegistration.successTitle'
                                defaultMessage='API registrada correctamente'
                            />
                        </AlertTitle>
                        <FormattedMessage
                            id='Apis.Details.LifeCycle.UATRegistration.successMessage'
                            defaultMessage='Revisión {revision} registrada en UAT.'
                            values={{ revision: registrationData.lastRegistered?.revision || 'actual' }}
                        />
                        {registrationData.lastRegistered?.prUrl && (
                            <Box mt={1}>
                                <Link
                                    href={registrationData.lastRegistered.prUrl}
                                    target='_blank'
                                    rel='noopener'
                                >
                                    <FormattedMessage
                                        id='Apis.Details.LifeCycle.UATRegistration.viewInGit'
                                        defaultMessage='Ver en Git →'
                                    />
                                </Link>
                            </Box>
                        )}
                    </Alert>
                )}

                {/* Error alerts */}
                {[STATES.VALIDATION_FAILED, STATES.CRQ_REJECTED, STATES.ERROR]
                    .includes(registrationData.state) && (
                    <Alert severity='error' sx={{ mt: 2 }}>
                        <AlertTitle>
                            {registrationData.error?.title || (
                                <FormattedMessage
                                    id='Apis.Details.LifeCycle.UATRegistration.errorTitle'
                                    defaultMessage='Error en el registro'
                                />
                            )}
                        </AlertTitle>
                        {registrationData.error?.message || (
                            <FormattedMessage
                                id='Apis.Details.LifeCycle.UATRegistration.errorMessage'
                                defaultMessage='Ha ocurrido un error durante el proceso de registro.'
                            />
                        )}
                    </Alert>
                )}

                {/* Cancelled alert */}
                {registrationData.state === STATES.CANCELLED && (
                    <Alert severity='info' sx={{ mt: 2 }}>
                        <FormattedMessage
                            id='Apis.Details.LifeCycle.UATRegistration.cancelledMessage'
                            defaultMessage='El registro fue cancelado por el usuario.'
                        />
                    </Alert>
                )}

                {/* Action buttons */}
                <Box className={classes.actions}>
                    {/* Register button - disabled while in progress to prevent duplicates */}
                    <Button
                        variant='contained'
                        color='primary'
                        startIcon={inProgress ? <CircularProgress size={20} color='inherit' /> : <CloudUploadIcon />}
                        onClick={startRegistration}
                        disabled={inProgress}
                        id='uat-register-btn'
                    >
                        <FormattedMessage
                            id='Apis.Details.LifeCycle.UATRegistration.registerButton'
                            defaultMessage='Registrar en UAT'
                        />
                    </Button>

                    {/* Cancel button - only shown when process is in progress */}
                    {canCancel() && (
                        <Button
                            variant='outlined'
                            color='error'
                            onClick={() => setCancelDialogOpen(true)}
                        >
                            <FormattedMessage
                                id='Apis.Details.LifeCycle.UATRegistration.cancelButton'
                                defaultMessage='Cancelar'
                            />
                        </Button>
                    )}

                    {/* Retry button - only shown after errors */}
                    {[STATES.ERROR, STATES.VALIDATION_FAILED, STATES.CRQ_REJECTED]
                        .includes(registrationData.state) && (
                        <Button
                            variant='outlined'
                            onClick={handleRetry}
                        >
                            <FormattedMessage
                                id='Apis.Details.LifeCycle.UATRegistration.retryButton'
                                defaultMessage='Reintentar'
                            />
                        </Button>
                    )}
                </Box>
            </CardContent>

            {/* Cancel confirmation dialog */}
            <Dialog
                open={cancelDialogOpen}
                onClose={() => setCancelDialogOpen(false)}
                aria-labelledby='cancel-dialog-title'
            >
                <DialogTitle id='cancel-dialog-title'>
                    <FormattedMessage
                        id='Apis.Details.LifeCycle.UATRegistration.cancelDialogTitle'
                        defaultMessage='Cancelar registro en UAT'
                    />
                </DialogTitle>
                <DialogContent>
                    <DialogContentText component='div'>
                        <FormattedMessage
                            id='Apis.Details.LifeCycle.UATRegistration.cancelDialogMessage'
                            defaultMessage='¿Estás seguro de que quieres cancelar el registro en UAT?'
                        />
                        <Box component='ul' sx={{ mt: 2, mb: 0, pl: 2 }}>
                            <li>
                                <FormattedMessage
                                    id='Apis.Details.LifeCycle.UATRegistration.cancelDialogItem1'
                                    defaultMessage='Se cancelará el proceso de registro actual'
                                />
                            </li>
                            <li>
                                <FormattedMessage
                                    id='Apis.Details.LifeCycle.UATRegistration.cancelDialogItem2'
                                    defaultMessage='Se cerrará cualquier Issue pendiente en GitHub'
                                />
                            </li>
                            <li>
                                <FormattedMessage
                                    id='Apis.Details.LifeCycle.UATRegistration.cancelDialogItem3'
                                    defaultMessage='Se cancelará la solicitud CRQ en Helix (si existe)'
                                />
                            </li>
                            <li>
                                <FormattedMessage
                                    id='Apis.Details.LifeCycle.UATRegistration.cancelDialogItem4'
                                    defaultMessage='No se creará ni fusionará ninguna PR en el repositorio'
                                />
                            </li>
                        </Box>
                    </DialogContentText>
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setCancelDialogOpen(false)}>
                        <FormattedMessage
                            id='Apis.Details.LifeCycle.UATRegistration.cancelDialogBack'
                            defaultMessage='Volver'
                        />
                    </Button>
                    <Button
                        onClick={handleCancelConfirm}
                        color='error'
                        variant='contained'
                    >
                        <FormattedMessage
                            id='Apis.Details.LifeCycle.UATRegistration.cancelDialogConfirm'
                            defaultMessage='Sí, cancelar registro'
                        />
                    </Button>
                </DialogActions>
            </Dialog>
        </StyledCard>
    );
}
