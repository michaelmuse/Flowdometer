import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class ViewAllDashboards extends NavigationMixin(LightningElement) {
    handleOpenDashboards() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/lightning/n/Flowdometer__Command_Center'
            }
        });
    }
}