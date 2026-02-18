import { LightningElement } from 'lwc';
import checkConnectionStatus from '@salesforce/apex/FlowdometerAuthService.checkConnectionStatus';
import getOrgDomainUrl from '@salesforce/apex/FlowdometerAuthService.getOrgDomainUrl';
import getNamedCredentialSetupUrl from '@salesforce/apex/FlowdometerAuthService.getNamedCredentialSetupUrl';
import getExternalCredentialAuthUrl from '@salesforce/apex/FlowdometerAuthService.getExternalCredentialAuthUrl';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class FlowdometerAuthSetup extends LightningElement {
    isLoading = true;
    isConnected = false;
    statusMessage = 'Checking connection...';
    errorDetails = '';
    orgDomain = '';

    connectedCallback() {
        this.initialize();
    }

    async initialize() {
        try {
            // Fetch org domain for display early
            const domain = await getOrgDomainUrl();
            this.orgDomain = domain;
        } catch (e) {
            // Non-blocking; continue
        } finally {
            await this.validateConnection(true);
        }
    }

    async validateConnection(initial = false) {
        this.isLoading = true;
        try {
            const status = await checkConnectionStatus();
            this.isConnected = !!status.connected;
            this.statusMessage = status.message || (this.isConnected ? 'Connected' : 'Not Connected');

            // Prefer orgDomain from server if provided
            if (status.orgDomainUrl) {
                this.orgDomain = status.orgDomainUrl;
            }

            // Stash links for button handlers
            this._ncUrl = status.namedCredentialSetupUrl;
            this._ecUrl = status.externalCredentialAuthUrl;

            this.errorDetails = status.errorDetails || '';

            if (this.isConnected && !initial) {
                this.showToast('Success', 'Flowdometer is authorized and ready.', 'success');
            }

            // Fire authsuccess to unblock parent when connected
            if (this.isConnected) {
                this.dispatchEvent(new CustomEvent('authsuccess'));
            }
        } catch (error) {
            // Resilient, admin-friendly error
            const msg = error && error.body && error.body.message ? error.body.message : (error && error.message) ? error.message : 'Unknown error';
            this.statusMessage = 'Unable to verify connection. Please try Validate Connection.';
            this.errorDetails = msg;
            this.isConnected = false;
        } finally {
            this.isLoading = false;
        }
    }

    handleValidate = () => {
        this.validateConnection(false);
    };

    handleOpenNamedCredential = async () => {
        try {
            if (!this._ncUrl) {
                this._ncUrl = await getNamedCredentialSetupUrl();
            }
            if (this._ncUrl) {
                window.open(this._ncUrl, '_blank', 'noopener');
            } else {
                this.showToast('Setup Unavailable', 'Unable to open Named Credential. Please navigate via Setup.', 'warning');
            }
        } catch (e) {
            this.showToast('Error', 'Failed to open Named Credential setup.', 'error');
        }
    };

    handleOpenExternalCredential = async () => {
        try {
            if (!this._ecUrl) {
                this._ecUrl = await getExternalCredentialAuthUrl();
            }
            if (this._ecUrl) {
                window.open(this._ecUrl, '_blank', 'noopener');
            } else {
                this.showToast('Setup Unavailable', 'Unable to open External Credentials. Please navigate via Setup.', 'warning');
            }
        } catch (e) {
            this.showToast('Error', 'Failed to open External Credentials.', 'error');
        }
    };

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
