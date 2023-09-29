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

    connectedCallback() {
        this.initialLoading = true;
        console.log("isLoading initially set to:", this.isLoading);
    }

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
        if (data) {
            let picklistOptions = [];
            console.log('data ==> '+JSON.stringify(data));
            for (let key in data) {
                picklistOptions.push({value:key, label:data[key]});
            }
            this.sObjectOptions = picklistOptions;
            console.log(JSON.stringify(this.sObjectOptions));
        } else if (error) {
            window.console.log("error ====> " + JSON.stringify(error));
        }
    }

    handleSObjectChange(event){
        this.selectedSObject = event.target.value;
        console.log('Target Value Object -'+JSON.stringify(event.detail.value));
        console.log('Detail Value Object -'+JSON.stringify(event.target.value));
    }

    @wire(getSObjectFields,{ objectName: "$selectedSObject" })
    getSObjectFields({ error, data }) {
        console.log('isLoading initially set to:', this.isLoading);
        Promise.resolve().then(() => {
            this.isLoading = false;
        });
        console.log('isLoading changed to:', this.isLoading);
        console.log(JSON.stringify(data));
        console.log("this in @wire", this);
        if (data) {
            let picklistOptions = [];
            for (let key in data) {
                picklistOptions.push({value:key, label:data[key]});
            }
            this.sObjectFieldsOptions = picklistOptions;
            console.log(JSON.stringify(this.sObjectFieldsOptions));
        } else if (error) {
            console.log("error ====> " + JSON.stringify(error));
        }
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

    handleSubmitValidation(){
        this.isLoading = true;
        checkFieldHistoryStatus({ sObjectAPIName: this.selectedSObject, fieldName: this.selectedField })
            .then((result) => {
                this.fieldHistoryStatus = result;
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
                    this.isLoading = false;
                } else if(this.fieldHistoryStatus === 'HISTORY_NOT_ENABLED_EARLIER_BUT_ENABLED_NOW' || this.fieldHistoryStatus === 'HISTORY_ENABLED_ALREADY' || this.fieldHistoryStatus === 'HISTORY_ENABLED_HAS_LIMITS'){
                    window.close();
                    this.createListenerRec();
                    this.isLoading = false;
                } else{
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Something went wrong',
                            message: 'Something went wrong. Please try again.',
                            variant: 'error',
                        }),
                    );
                    this.isLoading = false;
                }
            })
            .catch((error) => {
                this.error = error;
                this.fieldHistoryStatus = undefined;
                this.isLoading = false;
            });
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