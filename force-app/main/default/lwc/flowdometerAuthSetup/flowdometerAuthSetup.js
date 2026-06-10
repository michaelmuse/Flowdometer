import { LightningElement } from 'lwc';
import checkConnectionStatus from '@salesforce/apex/FlowdometerAuthService.checkConnectionStatus';
import completeSetup from '@salesforce/apex/FlowdometerAuthService.completeSetup';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class FlowdometerAuthSetup extends LightningElement {
    isLoading = true;
    isConnected = false;
    errorDetails = '';
    setupAttempted = false;

    get showTroubleshooting() {
        return this.setupAttempted && this.errorDetails;
    }

    connectedCallback() {
        // Permission reconciliation (Build Plan A.0) is triggered by the parent
        // listenerMasterConfiguration on every setup entry, so it is intentionally
        // NOT called here (this component mounts only while disconnected).
        this.checkConnection(true);
    }

    async checkConnection(initial = false) {
        this.isLoading = true;
        try {
            const status = await checkConnectionStatus();
            this.isConnected = !!status.connected;

            if (!this.isConnected && !this.setupAttempted) {
                this.errorDetails = '';
            } else if (!this.isConnected) {
                this.errorDetails = status.errorDetails || '';
            }

            if (this.isConnected && !initial) {
                this.showToast('Success', 'Flowdometer is connected and ready.', 'success');
            }

            if (this.isConnected) {
                this.dispatchEvent(new CustomEvent('authsuccess'));
            }
        } catch (error) {
            this.isConnected = false;
            if (this.setupAttempted) {
                this.errorDetails = error?.body?.message || error?.message || 'Unknown error';
            }
        } finally {
            this.isLoading = false;
        }
    }

    handleValidate = () => {
        this.checkConnection(false);
    };

    async fetchApiSession() {
        const urls = ['/apex/FlowdometerSession', '/apex/Flowdometer__FlowdometerSession'];
        for (const url of urls) {
            try {
                const res = await fetch(url, { credentials: 'same-origin' });
                if (!res.ok) continue;
                const text = await res.text();
                const data = JSON.parse(text.trim());
                if (data.sid) return data.sid;
            } catch (_) { /* try next URL */ }
        }
        return null;
    }

    handleCompleteSetup = async () => {
        this.isLoading = true;
        this.setupAttempted = true;
        try {
            const apiSession = await this.fetchApiSession();
            await completeSetup({ apiSessionId: apiSession });
            this.showToast('Setup Complete', 'Connection configured. Validating...', 'success');
            await this.checkConnection(false);
        } catch (error) {
            const msg = error?.body?.message || error?.message || 'Setup could not be completed.';
            this.showToast('Setup Incomplete', 'Try running setup again, or contact help@flowdometer.com.', 'warning');
            this.errorDetails = msg;
            this.isLoading = false;
        }
    };

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
