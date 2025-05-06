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
    @track enableHistory;
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
            // Additional validation before making the server call
            if (!this.selectedSObject || !this.selectedField) {
                throw new Error('Please select both an object and a field to track.');
            }

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

            // If the response starts with WARNING, show it as a warning but proceed
            if (this.fieldHistoryStatus && this.fieldHistoryStatus.startsWith('WARNING:')) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: "Warning",
                        message: this.fieldHistoryStatus,
                        variant: "warning",
                        mode: "sticky"
                    })
                );
                // Continue despite warning
                await this.createListenerRec();
            }
            // If the response starts with ERROR, show it as an error and stop
            else if (this.fieldHistoryStatus && this.fieldHistoryStatus.startsWith('ERROR:')) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: "Error",
                        message: this.fieldHistoryStatus.substring(6), // Remove 'ERROR:' prefix
                        variant: "error",
                        mode: "sticky"
                    })
                );
                this.toggleLoading(); // Re-enable the form
            }
            else if (this.fieldHistoryStatus === "HISTORY_ENABLED_HAS_NO_LIMITS") {
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
            
            // Display a more user-friendly error message based on the error type
            let errorMessage = error.body ? error.body.message : (error.message || 'Unknown error');
            
            // Handle specific error cases
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
            
            // Re-enable the form
            this.toggleLoading();
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

        this.isNavigatingAway = false; // Flag to track if navigation is in progress

        createListenerRecord({ newRecord: listener })
            .then((result) => {
                console.log("Listener created with ID: " + result);
                
                // Set flag to prevent duplicate navigation
                if (this.isNavigatingAway) return;
                this.isNavigatingAway = true;
                
                // Show success message before navigation
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: "Success",
                        message: "Listener record created successfully",
                        variant: "success"
                    })
                );
                
                // Add a small delay before navigation to ensure toast is visible
                setTimeout(() => {
                    try {
                        this[NavigationMixin.Navigate](
                            {
                                type: "standard__recordPage",
                                attributes: {
                                    recordId: result,
                                    objectApiName: "Flowdometer__Listener__c",
                                    actionName: "view"
                                }
                            },
                            // Set replace to false to maintain browser history
                            false
                        );
                        
                        // Close action only after successful navigation
                        this.closeAction();
                    } catch (navError) {
                        console.error("Navigation error: ", navError);
                        // If navigation fails, still show the record was created
                        this.dispatchEvent(
                            new ShowToastEvent({
                                title: "Created Successfully",
                                message: "Listener was created but there was an issue with navigation. Please check the Listeners tab.",
                                variant: "success",
                                mode: "sticky"
                            })
                        );
                        
                        // Safer fallback navigation to the object home
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
                
                this.selectedField = undefined;
            })
            .catch((error) => {
                console.error("Error creating listener: ", JSON.stringify(error));
                this.error = error;
                
                // Show detailed error to user
                let errorMessage = error.body?.message || error.message || 'Unknown error';
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: "Error Creating Listener",
                        message: errorMessage,
                        variant: "error",
                        mode: "sticky"
                    })
                );
                
                // Re-enable form
                this.toggleLoading();
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
