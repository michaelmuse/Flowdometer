import { LightningElement, track, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import getAllSObjectsInOrg from '@salesforce/apex/MetaDataUtilityCls.getAllSObjectsInOrg';
import getSObjectFields from '@salesforce/apex/MetaDataUtilityCls.getSObjectFields';
import checkFieldHistoryStatus from '@salesforce/apex/MetaDataUtilityCls.checkFieldHistoryStatus';
import createListenerRecord from '@salesforce/apex/MetaDataUtilityCls.createListenerRecord';

export default class ListenerMasterConfiguration extends NavigationMixin(LightningElement) {
    @track showRadio = false;
    keyIndex = 0;
    @api selectedSObject;
    @track selectedField;
    @track sObjectOptions = [];
    @track sObjectFieldsOptions = [];
    @track selectedRadio;
    @api isLoading = false;
    @api initialLoading = false;
    @track configName;
    @track description;
    @track type;
    @track valueType;
    @track terminalStage;
    @track radioValue = 'All Records';
    @track recordIdVal;
    fieldHistoryStatus;
    @api error;
    @api recordId;

    handleChanges(event){
        const fieldName = event.target.name;
        if(fieldName == 'configName'){
            this.configName = event.target.value;
            console.log('configValue - '+JSON.stringify(this.configName));
        } else if(fieldName == 'type'){
            this.type = event.target.value;
            console.log('type - '+JSON.stringify(this.type));
        } else if(fieldName == 'terminalStage'){
            this.terminalStage = event.target.value;
        } else{

        }
    }

    get options() {
        return [
            { label: 'All Records', value: 'All Records' },
            { label: 'Individual Records', value: 'Individual Records' }
        ];
    }
    
    @track itemList = [
        {
            id: 0
        }
    ];

    addRow() {
        ++this.keyIndex;
        var newItem = [{ id: this.keyIndex }];
        this.itemList = this.itemList.concat(newItem);
    }

    removeRow(event) {
        if (this.itemList.length >= 2) {
            this.itemList = this.itemList.filter(function (element) {
                return parseInt(element.id) !== parseInt(event.target.accessKey);
            });
        }
    }

    @wire(getAllSObjectsInOrg, {})
    getAllSObjectsInOrg({error, data}){
        this.initialLoading = true;
        console.log('initialLoading initially set to:', this.initialLoading);
        console.log('stringified JSON initially'+ JSON.stringify(data));
        if (data) {
            let picklistOptions = [];
            console.log('data ==> '+JSON.stringify(data));
            for (let key in data) {
                picklistOptions.push({value:key, label:data[key]});
            }
            this.sObjectOptions = picklistOptions;
            console.log('JSON stringicy in IF' + JSON.stringify(this.sObjectOptions));
            this.updateLoadingStatus();
        } else if (error) {
            window.console.log("error ====> " + JSON.stringify(error));
            this.updateLoadingStatus();
        }
        // this.initialLoading = false;
        // console.log('initialLoading changed to:', this.initialLoading);
    }

    @wire(getSObjectFields,{ objectName: "$selectedSObject" })
    getSObjectFields({ error, data }) {
        if (data) {
            let picklistOptions = [];
            for (let key in data) {
                picklistOptions.push({value:key, label:data[key]});
            }
            this.sObjectFieldsOptions = picklistOptions;
            console.log(JSON.stringify(this.sObjectFieldsOptions));
            this.updateLoadingStatus();
            console.log('initialLoading changed to:', this.initialLoading);
        } else if (error) {
            console.log("error ====> " + JSON.stringify(error));
            this.updateLoadingStatus();
            console.log('initialLoading changed to:', this.initialLoading);
        }
    }
    
    updateLoadingStatus() {
        console.log('sObjectOptions - '+this.sObjectOptions);
        console.log('sObjectFieldsOptions - '+this.sObjectFieldsOptions);
        if (this.sObjectOptions && this.sObjectFieldsOptions) {
            this.initialLoading = false;
            console.log('initialLoading set to False');
        }
    }

    handleSObjectChange(event){
        this.selectedSObject = event.target.value;
        console.log('Target Value Object -'+JSON.stringify(event.detail.value));
        console.log('Detail Value Object -'+JSON.stringify(event.target.value));
    }

    handleFieldChange(event){
        this.selectedField = event.target.value;
        console.log('Target Value Field -'+JSON.stringify(event.target.value));
        console.log('Detail Value Field -'+JSON.stringify(event.detail.value));
    }

    handleRadioChange(event) {
        const selectedOption = event.detail.value;
        console.log('selectedRadio with value: ' + selectedOption);
        if(selectedOption == "Individual Records"){
            this.showRadio = true;
        } else{
            this.showRadio = false;
        }
    }

    async handleSubmitValidation(){
        this.isLoading = true;
        try {
            // Wait for the checkFieldHistoryStatus to complete
            this.fieldHistoryStatus = await checkFieldHistoryStatus({ sObjectAPIName: this.selectedSObject, fieldName: this.selectedField });
            this.error = undefined;
            console.log('Value - '+JSON.stringify(this.fieldHistoryStatus));

            if(this.fieldHistoryStatus === 'HISTORY_ENABLED_HAS_NO_LIMITS'){
                console.log('Inside - '+JSON.stringify(this.fieldHistoryStatus));
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'History Limit Reached',
                        message: 'History is enabled for '+this.selectedSObject+' object already, but you already have the maximum number of fields with history tracking. Please remove one field from history tracking.',
                        variant: 'error',
                    }),
                );
            } else if(this.fieldHistoryStatus === 'HISTORY_NOT_ENABLED_EARLIER_BUT_ENABLED_NOW' || this.fieldHistoryStatus === 'HISTORY_ENABLED_ALREADY' || this.fieldHistoryStatus === 'HISTORY_ENABLED_HAS_LIMITS'){
                window.close();
                // Wait for the createListenerRec to complete
                await this.createListenerRec();
            } else {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Something went wrong',
                        message: 'Something went wrong. Please try again.',
                        variant: 'error',
                    }),
                );
            }
        } catch (error) {
            this.error = error;
            this.fieldHistoryStatus = undefined;
        } finally {
            this.isLoading = false;  // Ensure this is set to false only after all async operations are done.
        }
    }

    createListenerRec(){
        let listener = { 'sobjectType': 'Flowdometer__Listener__c' };
        listener.Name = this.selectedSObject + ' - ' + this.selectedField + ': Listener';
        listener.Flowdometer__Object_Name__c = this.selectedSObject;
        listener.Flowdometer__Field_To_Track__c = this.selectedField;
        listener.Flowdometer__Type__c = this.type;
        listener.Flowdometer__TerminalStage__c = this.terminalStage;

        createListenerRecord({newRecord: listener})
        .then(result => {
            this.recordId = result;
            console.log(result);
            this.closeAction();
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.recordId,
                    objectApiName: 'Flowdometer__Listener__c',
                    actionName: 'view'
                }
            }, true);
        })
        .catch(error => {
            console.log(JSON.stringify(error));
            this.error = error;
        });
    }

    // handle error from child components
    errorCallback(error, stack){
        this.error = error;
    }
    
    // handle errors from self (submit button press)
    handleFormError(event){
        this.error = event.detail;
    }
    
    // handle errors from self
    handleError(error){
        this.error =  error;   
    }

    closeAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleCancel(event){
        this.closeAction();
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
            objectApiName: 'Flowdometer__Listener__c',
            actionName: 'list'
        },
            state: {
            filterName: 'Recent'
        }});
    }
}