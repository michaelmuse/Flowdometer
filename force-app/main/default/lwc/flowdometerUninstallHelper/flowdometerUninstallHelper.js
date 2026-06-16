import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import prepareForUninstall from '@salesforce/apex/FlowdometerUninstallHelper.prepareForUninstall';

export default class FlowdometerUninstallHelper extends LightningElement {
    isLoading = false;
    showResult = false;
    success = false;
    resultMessage = '';
    manualEraseRequired = false;

    get buttonDisabled() {
        return this.isLoading || (this.showResult && this.success);
    }

    get resultClass() {
        return this.success
            ? 'slds-text-color_success slds-text-body_regular'
            : 'slds-text-color_error slds-text-body_regular';
    }

    // Fetch a Metadata-API-scoped session from the Flowdometer VF page
    // (Lightning sessions lack Metadata API scope), same approach as the
    // Connection Setup component.
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

    handlePrepare = async () => {
        this.isLoading = true;
        this.showResult = false;
        try {
            const apiSession = await this.fetchApiSession();
            const result = await prepareForUninstall({ apiSessionId: apiSession });

            this.success = !!result.success;
            this.resultMessage = result.message;
            this.manualEraseRequired = !!result.manualEraseRequired;
            this.showResult = true;

            this.dispatchEvent(new ShowToastEvent({
                title: 'Uninstall Preparation Complete',
                message: 'Flowdometer has been prepared for uninstall. Review the next steps below.',
                variant: 'success'
            }));
        } catch (error) {
            this.success = false;
            this.resultMessage = error?.body?.message || error?.message
                || 'Unknown error while preparing for uninstall.';
            this.showResult = true;
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: this.resultMessage,
                variant: 'error',
                mode: 'sticky'
            }));
        } finally {
            this.isLoading = false;
        }
    };
}
