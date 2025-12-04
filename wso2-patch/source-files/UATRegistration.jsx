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

const PREFIX = 'UATRegistration';

// =============================================================================
// GitHub Configuration for WSO2-Processor
// In production, these should come from environment/settings
// =============================================================================
const GITHUB_CONFIG = {
    owner: 'ISAngelRivera',           // GitHub org/user
    repo: 'WSO2-Processor',           // Repository that handles WSO2 events
    workflow: 'receive-uat-request.yml', // Workflow file to trigger
    // Token should be injected via WSO2 settings or environment
    // For MVP, we'll use a placeholder that should be configured
    getToken: () => {
        // Try to get from WSO2 settings first, then fallback
        const settings = window.__RUNTIME_CONFIG__?.GITHUB_TOKEN
            || localStorage.getItem('github_pat_token');
        return settings || null;
    },
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
 * Trigger GitHub workflow dispatch
 * @param {Object} apiData - API data to send
 * @returns {Promise<Object>} Response with success status and run info
 */
const triggerGitHubWorkflow = async (apiData) => {
    const token = GITHUB_CONFIG.getToken();

    if (!token) {
        throw new Error('GitHub token not configured. Set it in localStorage as "github_pat_token"');
    }

    const url = `https://api.github.com/repos/${GITHUB_CONFIG.owner}/${GITHUB_CONFIG.repo}/actions/workflows/${GITHUB_CONFIG.workflow}/dispatches`;

    const payload = {
        ref: 'main',
        inputs: {
            apiId: apiData.id,
            apiName: apiData.name,
            apiVersion: apiData.version,
            apiContext: apiData.context || '',
            userId: apiData.userId || 'unknown',
            timestamp: new Date().toISOString(),
            // Additional metadata as JSON string
            metadata: JSON.stringify({
                provider: apiData.provider || 'admin',
                type: apiData.type || 'HTTP',
                lifeCycleStatus: apiData.lifeCycleStatus || 'PUBLISHED',
            }),
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
        };
    }

    // Error handling
    const errorBody = await response.text();
    throw new Error(`GitHub API error (${response.status}): ${errorBody}`);
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
     * Execute a single step in the registration flow
     * @param {Object} step - Step configuration
     * @returns {Promise<boolean>} False if cancelled
     */
    const executeStep = (step) => {
        return new Promise((resolve) => {
            setTimeout(() => {
                if (!isMountedRef.current) {
                    resolve(false);
                    return;
                }
                const currentState = loadState(api.id);
                if (currentState.state === STATES.CANCELLED) {
                    resolve(false);
                    return;
                }
                setRegistrationData((prev) => ({ ...prev, state: step.state }));
                resolve(true);
            }, step.wait);
        });
    };

    /**
     * Start registration process
     * Triggers GitHub workflow in WSO2-Processor
     */
    const startRegistration = async () => {
        const startedAt = new Date().toISOString();
        setRegistrationData({ state: STATES.INITIATING, startedAt });

        try {
            // Step 1: Trigger GitHub workflow
            setRegistrationData((prev) => ({ ...prev, state: STATES.EXPORTING }));

            const apiData = {
                id: api.id,
                name: api.name,
                version: api.version,
                context: api.context,
                provider: api.provider,
                type: api.type,
                lifeCycleStatus: api.lifeCycleStatus,
                userId: 'current-user', // TODO: Get from auth context
            };

            await triggerGitHubWorkflow(apiData);

            // Step 2: Workflow triggered - now we wait for GitHub to process
            // The remaining steps happen in GitHub Actions:
            // - VALIDATING: Linters run in GIT-Helix-Processor
            // - REQUESTING_CRQ: Helix ticket creation
            // - CRQ_PENDING: Waiting for approval
            // - REGISTERING: Final storage

            // For MVP, we show a pending state and provide link to GitHub
            setRegistrationData((prev) => ({
                ...prev,
                state: STATES.VALIDATING,
                workflowTriggered: true,
                githubRepo: `${GITHUB_CONFIG.owner}/${GITHUB_CONFIG.repo}`,
            }));

            // Simulate progression for demo (in production, poll GitHub or use webhooks)
            const steps = [
                { state: STATES.REQUESTING_CRQ, wait: 3000 },
                { state: STATES.CRQ_PENDING, wait: 4000 },
                { state: STATES.REGISTERING, wait: 3000 },
            ];

            const executeAllSteps = async () => {
                for (let i = 0; i < steps.length; i += 1) {
                    // eslint-disable-next-line no-await-in-loop
                    const shouldContinue = await executeStep(steps[i]);
                    if (!shouldContinue) {
                        return;
                    }
                }

                // Success
                if (!isMountedRef.current) return;
                setRegistrationData((prev) => ({
                    ...prev,
                    state: STATES.REGISTERED,
                    lastRegistered: {
                        revision: `rev-${Date.now().toString(36)}`,
                        registeredAt: new Date().toISOString(),
                        prUrl: `https://github.com/${GITHUB_CONFIG.owner}/GIT-Helix-Processor/pulls`,
                    },
                }));

                MuiAlert.success(intl.formatMessage({
                    id: 'Apis.Details.LifeCycle.UATRegistration.success',
                    defaultMessage: 'API registrada en UAT correctamente',
                }));
            };

            executeAllSteps();
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
                    {!inProgress && (
                        <Button
                            variant='contained'
                            color='primary'
                            startIcon={<CloudUploadIcon />}
                            onClick={startRegistration}
                            id='uat-register-btn'
                        >
                            <FormattedMessage
                                id='Apis.Details.LifeCycle.UATRegistration.registerButton'
                                defaultMessage='Registrar en UAT'
                            />
                        </Button>
                    )}

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
                        defaultMessage='Cancelar registro'
                    />
                </DialogTitle>
                <DialogContent>
                    <DialogContentText>
                        <FormattedMessage
                            id='Apis.Details.LifeCycle.UATRegistration.cancelDialogMessage'
                            defaultMessage={
                                '¿Estás seguro de que quieres cancelar el registro en UAT? '
                                + 'Esta acción cancelará el proceso actual, cerrará cualquier PR '
                                + 'abierta y cancelará la CRQ en Helix si existe.'
                            }
                        />
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
                            defaultMessage='Sí, cancelar'
                        />
                    </Button>
                </DialogActions>
            </Dialog>
        </StyledCard>
    );
}
