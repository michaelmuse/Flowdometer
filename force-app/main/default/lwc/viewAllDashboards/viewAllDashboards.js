import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class ViewAllDashboards extends NavigationMixin(LightningElement) {
    handleOpenDashboards() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'Command_Center'
            }
        });
    }
}