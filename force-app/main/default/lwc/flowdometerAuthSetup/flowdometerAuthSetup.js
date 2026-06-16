import { LightningElement } from 'lwc';
import checkConnectionStatus from '@salesforce/apex/FlowdometerAuthService.checkConnectionStatus';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Stable Setup deep link to the External Client App Manager list. The packaged
// ECA's per-org record id is not knowable here, so we link to the list (opens in
// a new tab); the admin reaches Edit Policies in two documented clicks.
const ECA_MANAGER_URL = '/lightning/setup/ManageExternalClientApplication/home';
// Backstop poll so the connection is detected even if the focus/visibility
// events are missed. The focus + visibilitychange listeners are the primary path.
const POLL_INTERVAL_MS = 5000;

export default class FlowdometerAuthSetup extends LightningElement {
    isLoading = true;
    isConnected = false;
    errorDetails = '';
    manualCheckFailed = false;

    _pollId;
    _onWindowFocus;
    _onVisibilityChange;

    get ecaManagerUrl() {
        return ECA_MANAGER_URL;
    }

    get showTroubleshooting() {
        return this.manualCheckFailed && !this.isConnected && this.errorDetails;
    }

    connectedCallback() {
        // Permission reconciliation (Build Plan A.0) is triggered by the parent
        // listenerMasterConfiguration on every setup entry, so it is intentionally
        // NOT called here (this component mounts only while disconnected).
        this.checkConnection({ initial: true });
        this.startAutoDetect();
    }

    disconnectedCallback() {
        this.stopAutoDetect();
    }

    // Re-check when the admin returns from the External Client App Manager tab,
    // and poll periodically, so "Connected" is detected without a manual click.
    startAutoDetect() {
        this._onWindowFocus = () => this.checkConnection({ silent: true });
        this._onVisibilityChange = () => {
            if (document.visibilityState === 'visible') {
                this.checkConnection({ silent: true });
            }
        };
        window.addEventListener('focus', this._onWindowFocus);
        document.addEventListener('visibilitychange', this._onVisibilityChange);
        this._pollId = window.setInterval(
            () => this.checkConnection({ silent: true }),
            POLL_INTERVAL_MS
        );
    }

    stopAutoDetect() {
        if (this._pollId) {
            window.clearInterval(this._pollId);
            this._pollId = undefined;
        }
        if (this._onWindowFocus) {
            window.removeEventListener('focus', this._onWindowFocus);
            this._onWindowFocus = undefined;
        }
        if (this._onVisibilityChange) {
            document.removeEventListener('visibilitychange', this._onVisibilityChange);
            this._onVisibilityChange = undefined;
        }
    }

    async checkConnection({ initial = false, silent = false, manual = false } = {}) {
        if (!silent) {
            this.isLoading = true;
        }
        try {
            const status = await checkConnectionStatus();
            const wasConnected = this.isConnected;
            this.isConnected = !!status.connected;

            if (this.isConnected) {
                this.errorDetails = '';
                this.manualCheckFailed = false;
                this.stopAutoDetect();
                if (!initial && !wasConnected) {
                    this.showToast('Success', 'Flowdometer is connected and ready.', 'success');
                }
                this.dispatchEvent(new CustomEvent('authsuccess'));
            } else if (manual) {
                this.manualCheckFailed = true;
                this.errorDetails = status.errorDetails || '';
            }
        } catch (error) {
            this.isConnected = false;
            if (manual) {
                this.manualCheckFailed = true;
                this.errorDetails = error?.body?.message || error?.message || 'Unknown error';
            }
        } finally {
            if (!silent) {
                this.isLoading = false;
            }
        }
    }

    handleValidate = () => {
        this.checkConnection({ manual: true });
    };

    handleOpenEcaManager = () => {
        window.open(this.ecaManagerUrl, '_blank', 'noopener');
    };

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
