// noinspection InconsistentSalesforceApiVersion

import { LightningElement, track, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { NavigationMixin } from "lightning/navigation";
import { CloseActionScreenEvent } from "lightning/actions";
import getAllSObjectsInOrg from "@salesforce/apex/ListenerMasterConfigurationController.getAllSObjectsInOrg";
import getSObjectFields from "@salesforce/apex/ListenerMasterConfigurationController.getSObjectFields";
import checkFieldHistoryStatus from "@salesforce/apex/ListenerMasterConfigurationController.checkFieldHistoryStatus";
import createListenerRecord from "@salesforce/apex/ListenerMasterConfigurationController.createListenerRecord";

export default class ListenerMasterConfiguration extends NavigationMixin(
    LightningElement
) {
    isLoading = false;
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

    @wire(getAllSObjectsInOrg, {})
    getAllSObjectsInOrg({ error, data }) {
        this.toggleLoading();
        if (data) {
            let picklistOptions = [];
            for (let key in data) {
                picklistOptions.push({ value: key, label: data[key] });
            }
            console.log(`retrieved ${picklistOptions.length} sobjects`);
            this.sObjectOptions = picklistOptions;
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
                d;
            })
            .catch((error) => {
                console.error(JSON.stringify(error));
            });

        this.toggleLoading();
    }

    toggleLoading() {
        this.isLoading = !this.isLoading;
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
