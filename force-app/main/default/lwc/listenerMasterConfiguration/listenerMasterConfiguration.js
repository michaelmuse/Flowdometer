// noinspection InconsistentSalesforceApiVersion

import { LightningElement, track, api, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { NavigationMixin } from "lightning/navigation";
import { CloseActionScreenEvent } from "lightning/actions";
import getAllSObjectsInOrg from "@salesforce/apex/MetaDataUtilityCls.getAllSObjectsInOrg";
import getSObjectFields from "@salesforce/apex/MetaDataUtilityCls.getSObjectFields";
import checkFieldHistoryStatus from "@salesforce/apex/MetaDataUtilityCls.checkFieldHistoryStatus";
import createListenerRecord from "@salesforce/apex/MetaDataUtilityCls.createListenerRecord";

export default class ListenerMasterConfiguration extends NavigationMixin(
    LightningElement
) {
    isLoading = false;
    showRadio = false;
    keyIndex = 0;
    selectedSObject;
    @track selectedField;
    @track sObjectOptions = [];
    @track sObjectFieldsOptions = [];
    @track selectedRadio;
    @track configName;
    @track type;
    fieldHistoryStatus;
    error;
    @track itemList = [
        {
            id: 0
        }
    ];

    handleChanges(event) {
        const fieldName = event.target.name;
        if (fieldName === "configName") {
            this.configName = event.target.value;
            console.log("configValue - " + JSON.stringify(this.configName));
        } else if (fieldName === "type") {
            this.type = event.target.value;
            console.log("type - " + JSON.stringify(this.type));
        } else {
        }
    }

    get options() {
        return [
            { label: "All Records", value: "All Records" },
            { label: "Individual Records", value: "Individual Records" }
        ];
    }

    addRow() {
        ++this.keyIndex;
        var newItem = [{ id: this.keyIndex }];
        this.itemList = this.itemList.concat(newItem);
    }

    removeRow(event) {
        if (this.itemList.length >= 2) {
            this.itemList = this.itemList.filter(function (element) {
                return (
                    parseInt(element.id) !== parseInt(event.target.accessKey)
                );
            });
        }
    }

    @wire(getAllSObjectsInOrg, {})
    getAllSObjectsInOrg({ error, data }) {
        this.toggleLoading();
        //console.log('initialLoading initially set to:', this.isLoading);
        //console.log('stringified JSON initially'+ JSON.stringify(data));
        if (data) {
            let picklistOptions = [];
            //console.log('data ==> '+JSON.stringify(data));
            for (let key in data) {
                picklistOptions.push({ value: key, label: data[key] });
            }
            console.log(`retrieved ${picklistOptions.length} sobjects`);
            this.sObjectOptions = picklistOptions;
            //console.log('JSON stringify in IF' + JSON.stringify(this.sObjectOptions));
        } else if (error) {
            this.error = error;
        }

        this.toggleLoading();
    }

    callGetSobjectFields(selectedSObject) {
        getSObjectFields({ objectName: selectedSObject })
            .then((result) => {
                let picklistOptions = [];
                for (let key in result) {
                    picklistOptions.push({ value: key, label: result[key] });
                }
                this.sObjectFieldsOptions = picklistOptions;
                console.log(JSON.stringify(this.sObjectFieldsOptions));
                //console.log('initialLoading changed to:', this.isLoading);
            })
            .catch((error) => {
                console.error(JSON.stringify(error));
            });

        this.toggleLoading();
    }

    toggleLoading() {
        this.isLoading = !this.isLoading;
    }

    updateLoadingStatus() {
        console.log("sObjectOptions - " + this.sObjectOptions);
        console.log("sObjectFieldsOptions - " + this.sObjectFieldsOptions);
        if (this.sObjectOptions && this.sObjectFieldsOptions) {
            this.isLoading = false;
            console.log("initialLoading set to False");
        }
    }

    handleSObjectChange(event) {
        this.callGetSobjectFields(event.target.value);
        this.selectedSObject = event.target.value;
        this.toggleLoading();
        console.log(
            "Target Value Object -" + JSON.stringify(event.detail.value)
        );
        console.log(
            "Detail Value Object -" + JSON.stringify(event.target.value)
        );
    }

    handleFieldChange(event) {
        this.selectedField = event.target.value;
        console.log(
            "Target Value Field -" + JSON.stringify(event.target.value)
        );
        console.log(
            "Detail Value Field -" + JSON.stringify(event.detail.value)
        );
    }

    /*handleRadioChange(event) {
        const selectedOption = event.detail.value;
        console.log('selectedRadio with value: ' + selectedOption);
        if (selectedOption == "Individual Records") {
            this.showRadio = true;
        } else {
            this.showRadio = false;
        }
    }*/

    async handleSubmitValidation() {
        this.toggleLoading();
        console.log(
            "submission:" +
                this.selectedSObject +
                " - " +
                this.selectedField +
                ": Listener"
        ); // format is using API names, not labels
        try {
            // Wait for the checkFieldHistoryStatus to complete
            this.fieldHistoryStatus = await checkFieldHistoryStatus({
                sObjectApiName: this.selectedSObject,
                fieldName: this.selectedField
            });

            this.error = undefined;
            console.log(
                "fieldHistoryStatus Value - " +
                    JSON.stringify(this.fieldHistoryStatus)
            );

            if (this.fieldHistoryStatus === "HISTORY_ENABLED_HAS_NO_LIMITS") {
                console.log(
                    "Inside - " + JSON.stringify(this.fieldHistoryStatus)
                );
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: "History Limit Reached",
                        message:
                            "History is enabled for " +
                            this.selectedSObject +
                            " object already, but you already have the maximum number of fields with history tracking. Please remove one field from history tracking.",
                        variant: "error"
                    })
                );
            } else if (
                this.fieldHistoryStatus ===
                    "HISTORY_NOT_ENABLED_EARLIER_BUT_ENABLED_NOW" ||
                this.fieldHistoryStatus === "HISTORY_ENABLED_ALREADY" ||
                this.fieldHistoryStatus === "HISTORY_ENABLED_HAS_LIMITS"
            ) {
                //window.close();
                // Wait for the createListenerRec to complete
                await this.createListenerRec();
            } else {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: "Something went wrong",
                        message: "Something went wrong. Please try again.",
                        variant: "error"
                    })
                );
            }
        } catch (error) {
            this.error = error;
            this.fieldHistoryStatus = undefined;
        } finally {
            this.toggleLoading(); // Ensure this is set to false only after all async operations are done.
        }
    }

    createListenerRec() {
        let listener = { sobjectType: "Flowdometer__Listener__c" };
        listener.Name =
            this.selectedSObject + " - " + this.selectedField + ": Listener";
        listener.Flowdometer__Object_Name__c = this.selectedSObject;
        listener.Flowdometer__Field_To_Track__c = this.selectedField;
        listener.Flowdometer__Type__c = this.type;

        createListenerRecord({ newRecord: listener })
            .then((result) => {
                console.log(result);

                this[NavigationMixin.Navigate](
                    {
                        type: "standard__recordPage",
                        attributes: {
                            recordId: result,
                            objectApiName: "Flowdometer__Listener__c",
                            actionName: "view"
                        }
                    },
                    true
                );

                this.closeAction();
                this.selectedField = undefined;
            })
            .catch((error) => {
                console.log(JSON.stringify(error));
                this.error = error;
            });
    }

    // handle error from child components
    errorCallback(error, stack) {
        this.error = error;
    }

    // handle errors from self (submit button press)
    handleFormError(event) {
        this.error = event.detail;
    }

    // handle errors from self
    handleError(error) {
        this.error = error;
    }

    closeAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleCancel(event) {
        this.closeAction();
        this[NavigationMixin.Navigate]({
            type: "standard__objectPage",
            attributes: {
                objectApiName: "Flowdometer__Listener__c",
                actionName: "list"
            },
            state: {
                filterName: "Recent"
            }
        });
    }

    get typeHelpText() {
        return (
            "OPTIONAL: Type should be blank unless you plan on having different goal times for different Types of this object (ie: New Business vs Renewal Opportunities may expect different sales cycle times).\n" +
            " If so, put the API Name of the field you are using to identify these types here in the Type field. If you need to combine two or more fields to get all Type permutations, you can build a formula field to concatenate them, and pass that in here." +
            " Use the API Name here, so for custom fields, it should end with __c."
        );
    }
}
