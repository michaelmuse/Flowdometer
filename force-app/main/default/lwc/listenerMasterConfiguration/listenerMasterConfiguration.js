// noinspection InconsistentSalesforceApiVersion

import { LightningElement, api, track, wire } from "lwc";
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
    @api isLoading = false;
    @api initialLoading = false;
    @api recordId;
    keyIndex = 0;
    @api selectedSObject;
    @track selectedField;
    @track sObjectOptions = [];
    @track sObjectFieldsOptions = [];
    @track selectedRadio;
    @track configName;
    @track type;
    @track enableHistory;
    fieldHistoryStatus;
    @api error;
    @track itemList = [
        {
            id: 0
        }
    ];
    @track typeFieldOptions = [];

    handleChanges(event) {
        const fieldName = event.target.name;
        if (fieldName === "configName") {
            this.configName = event.target.value;
            console.log("configValue - " + JSON.stringify(this.configName));
        } else if (fieldName === "type") {
            this.type = event.target.value;
            console.log("type - " + JSON.stringify(this.type));
        } else if (fieldName === "enableHistory") {
            this.enableHistory = event.target.checked;
            console.log(
                "enableHistory - " + JSON.stringify(this.enableHistory)
            );
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
            // Sort by label
            picklistOptions.sort((a, b) => a.label.localeCompare(b.label));
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
                // Sort by label
                picklistOptions.sort((a, b) => a.label.localeCompare(b.label));
                this.sObjectFieldsOptions = picklistOptions;
                this.typeFieldOptions = picklistOptions;
                console.log(JSON.stringify(this.sObjectFieldsOptions));
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

    handleTypeChange(event) {
        this.type = event.target.value;
        console.log("Type Field - " + JSON.stringify(event.target.value));
        if (this.type === this.selectedField) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Error",
                    message: "Type field cannot be the same as Field to Track.",
                    variant: "error",
                    mode: "sticky"
                })
            );
            this.type = undefined;
        }
    }

    async handleSubmitValidation() {
        this.toggleLoading();
        console.log(
            "submission:" +
                this.selectedSObject +
                " - " +
                this.selectedField +
                " - " +
                this.type +
                ": Listener"
        );
        try {
            if (!this.selectedSObject || !this.selectedField || !this.type) {
                this.isLoading = false;
                throw new Error('Please select an object, a field to track, and a type field.');
            }

            this.fieldHistoryStatus = await checkFieldHistoryStatus({
                sObjectApiName: this.selectedSObject,
                fieldName: this.selectedField
            });

            this.error = undefined;
            console.log(
                "fieldHistoryStatus Value - " +
                    JSON.stringify(this.fieldHistoryStatus)
            );

            if (this.fieldHistoryStatus && this.fieldHistoryStatus.startsWith('WARNING:')) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: "Warning",
                        message: this.fieldHistoryStatus,
                        variant: "warning",
                        mode: "sticky"
                    })
                );
                await this.createListenerRec();
            } else if (this.fieldHistoryStatus && this.fieldHistoryStatus.startsWith('ERROR:')) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: "Error",
                        message: this.fieldHistoryStatus.substring(6),
                        variant: "error",
                        mode: "sticky"
                    })
                );
                this.isLoading = false;
            } else if (this.fieldHistoryStatus === "HISTORY_ENABLED_HAS_NO_LIMITS") {
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
                this.isLoading = false;
            } else if (
                this.fieldHistoryStatus ===
                    "HISTORY_NOT_ENABLED_EARLIER_BUT_ENABLED_NOW" ||
                this.fieldHistoryStatus === "HISTORY_ENABLED_ALREADY" ||
                this.fieldHistoryStatus === "HISTORY_ENABLED_HAS_LIMITS"
            ) {
                await this.createListenerRec();
            } else {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: "Something went wrong",
                        message: "Something went wrong. Please try again.",
                        variant: "error"
                    })
                );
                this.isLoading = false;
            }
        } catch (error) {
            this.error = error;
            this.fieldHistoryStatus = undefined;
            
            let errorMessage = error.body ? error.body.message : (error.message || 'Unknown error');
            
            if (errorMessage.includes('Read timed out') || errorMessage.includes('CalloutException')) {
                errorMessage = 'The operation timed out. This might be due to the complexity of the object structure or network issues. Please try again or choose a different object.';
            } else if (errorMessage.includes('bounds')) {
                errorMessage = 'There was an error processing the object names. Please try a different object or contact your administrator.';
            }
            
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Error",
                    message: errorMessage,
                    variant: "error",
                    mode: "sticky"
                })
            );
            
            this.isLoading = false;
        }
    }

    // Add this new method to reset all form fields
    resetForm() {
        // Reset all the form fields
        this.selectedSObject = undefined;
        this.selectedField = undefined;
        this.type = undefined;
        this.enableHistory = false;
        this.sObjectFieldsOptions = [];
        this.typeFieldOptions = [];
        this.fieldHistoryStatus = undefined;
        
        // Reset any UI elements that need to be refreshed
        const toggleElement = this.template.querySelector('lightning-input[name="enableHistory"]');
        if (toggleElement) {
            toggleElement.checked = false;
        }
    }

    createListenerRec() {
        let listener = { sobjectType: "Flowdometer__Listener__c" };
        listener.Name =
            this.selectedSObject + " - " + this.selectedField + ": Listener";
        listener.Flowdometer__Object_Name__c = this.selectedSObject;
        listener.Flowdometer__Field_To_Track__c = this.selectedField;
        listener.Flowdometer__Type__c = this.type;
        listener.Flowdometer__Enable_History__c = this.enableHistory;

        this.isNavigatingAway = false;

        createListenerRecord({ newRecord: listener })
            .then((result) => {
                console.log("Listener created with ID: " + result);
                
                // Always stop the spinner first, regardless of navigation outcome
                this.isLoading = false;
                
                // Reset form fields for a clean slate when the user returns
                this.resetForm();
                
                if (this.isNavigatingAway) return;
                this.isNavigatingAway = true;
                
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: "Success",
                        message: "Listener record created successfully",
                        variant: "success"
                    })
                );
                
                setTimeout(() => {
                    try {
                        // Navigate to the record detail page for the created Listener
                        this[NavigationMixin.Navigate](
                            {
                                type: "standard__recordPage",
                                attributes: {
                                    recordId: result,
                                    objectApiName: "Flowdometer__Listener__c",
                                    actionName: "view"
                                }
                            },
                            false
                        );
                        
                        this.closeAction();
                    } catch (navError) {
                        console.error("Navigation error: ", navError);
                        
                        // Fallback navigation to the Listener list view if navigation fails
                        this.dispatchEvent(
                            new ShowToastEvent({
                                title: "Created Successfully",
                                message: "Listener was created but there was an issue with navigation. Please check the Listeners tab.",
                                variant: "success",
                                mode: "sticky"
                            })
                        );
                        
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
                }, 100);
            })
            .catch((error) => {
                console.error("Error creating listener: ", JSON.stringify(error));
                this.error = error;
                
                let errorMessage = error.body?.message || error.message || 'Unknown error';
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: "Error Creating Listener",
                        message: errorMessage,
                        variant: "error",
                        mode: "sticky"
                    })
                );
                
                // Ensure the spinner is stopped on error
                this.isLoading = false;
            });
    }

    errorCallback(error, stack) {
        this.error = error;
    }

    handleError(error) {
        this.error = error;
    }

    closeAction() {
        // Ensure spinner is stopped before closing
        this.isLoading = false;
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleCancel(event) {
        // Ensure spinner is stopped before navigating away
        this.isLoading = false;
        
        // Reset form fields for a clean slate
        this.resetForm();
        
        this.closeAction();
        
        // Navigate to the Listener list view
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

    // Add this method to reset the form when the component is initialized
    connectedCallback() {
        // Reset form fields when component is loaded
        this.resetForm();
    }

    // Add this method to ensure proper cleanup when the component is removed from the DOM
    disconnectedCallback() {
        // Make sure to clean up any state when the component is destroyed
        this.isLoading = false;
        this.isNavigatingAway = false;
    }

    get typeHelpText() {
        return (
            "OPTIONAL: Type should be blank unless you plan on having different goal times for different Types of this object (ie: New Business vs Renewal Opportunities may expect different sales cycle times).\n" +
            " If so, put the API Name of the field you are using to identify these types here in the Type field. If you need to combine two or more fields to get all Type permutations, you can build a formula field to concatenate them, and pass that in here." +
            " Use the API Name here, so for custom fields, it should end with __c."
        );
    }
}
