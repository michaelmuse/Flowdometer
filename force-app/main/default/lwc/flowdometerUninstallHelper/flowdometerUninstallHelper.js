import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import deactivateFlows from '@salesforce/apex/FlowdometerUninstallHelper.deactivateFlows';

export default class FlowdometerUninstallHelper extends LightningElement {
    @track isLoading = false;
    @track deactivationStatus = {
        success: false,
        message: '',
        deactivatedCount: 0,
        showMessage: false
    };

    // Handle click on the deactivate flows button
    async handleDeactivateFlows() {
        this.isLoading = true;
        this.deactivationStatus.showMessage = false;
        
        try {
            // Call the Apex method to deactivate flows
            const deactivatedCount = await deactivateFlows();
            
            this.deactivationStatus = {
                success: true,
                message: `Successfully deactivated ${deactivatedCount} flows. You can now uninstall the package.`,
                deactivatedCount: deactivatedCount,
                showMessage: true
            };
            
            // Show success toast
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: this.deactivationStatus.message,
                    variant: 'success'
                })
            );
        } catch (error) {
            // Handle errors
            const errorMessage = error.body?.message || 'Unknown error occurred while deactivating flows';
            
            this.deactivationStatus = {
                success: false,
                message: `Error: ${errorMessage}`,
                deactivatedCount: 0,
                showMessage: true
            };
            
            // Show error toast
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: errorMessage,
                    variant: 'error',
                    mode: 'sticky'
                })
            );
        } finally {
            this.isLoading = false;
        }
    }
    
    get statusVariant() {
        return this.deactivationStatus.success ? 'success' : 'error';
    }
    
    get buttonDisabled() {
        return this.isLoading || (this.deactivationStatus.success && this.deactivationStatus.deactivatedCount > 0);
    }
} 