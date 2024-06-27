//force-app/main/default/lwc/flowdometerInstructions/flowdometerInstructions.js
import { LightningElement, api, track } from "lwc";

export default class FlowdometerInstructions extends LightningElement {
    // Define the array of steps for the Welcome Mat
    @track steps = [
        {
            label: "Tracking",
            description:
                "Next, set up listeners to track changes to fields over time here:",
            completed: false,
            tileClass: "slds-welcome-mat__tile",
            content: "https://on.driveway.app/guides/bLekwqW/embed",
            iconName: "standard:stethoscope"
        },
        {
            label: "Goals / SLAs",
            description: "Last, set up your goals here:",
            completed: false,
            tileClass: "slds-welcome-mat__tile",
            content: "https://on.driveway.app/guides/0LYOe0W/embed",
            iconName: "standard:service_appointment"
        },
        {
            label: "Extending Flowdometer",
            iconName: "standard:capslock",
            description:
                "Flowdometer is an open-source project that is designed to be built on top of. The Flow and Step objects can be added to with whatever fields are necessary for your use case.\n\n" +
                "Flowdometer data on my tracked record\n" +
                "For example, you might build an automation to have your tracked object point at the Flow Tracker record that is tracking it. This would allow you to then pull in the data from the Flow record, and Most Recent Step record, including goal attainment progress bars, and put them directly on the tracked object. Imagine sorting all your opportunities by Next Breach At.\n\n" +
                "Business Hours\n" +
                'Another example, Flowdometer doesn’t support business hours out of the box, but we’ve included another open source project from Unofficial SF that will allow you to calculate these times in Flow Builder. In Flow Builder, check out the flow template we made called "Flowdometer - Autocalculate Business Hours". In there, you\'ll see how you can use an Action (created by Professor Flow - thank you!) that will allow you to create whatever rules you have for different business hours in your company, and calculate them with this action.'
        }
    ];

    // Add a new property to track the state of the toggle
    @track isStepCompleted = false;

    // Add a new method to handle the toggle change
    handleToggleChange(event) {
        this.isStepCompleted = event.target.checked;
        // Update the step's completed status here
    }

    // Expose steps for testing
    @api getSteps() {
        return this.steps;
    }

    // Tracked property to manage the state of the modal
    @track isModalOpen = false;

    // Property to hold the current content for the modal
    currentModalContent = "";

    // Dynamic class getter for each tile in the welcome mat
    get tileClass() {
        return this.steps.map((step) =>
            step.completed
                ? "slds-welcome-mat__tile slds-welcome-mat__tile_complete"
                : "slds-welcome-mat__tile"
        );
    }

    // Update the property when a step is clicked and open the modal
    handleStepCompleted(event) {
        console.log("handleStepCompleted called");
        const stepIndex = event.currentTarget.dataset.index;
        const newSteps = JSON.parse(JSON.stringify(this.steps)); // Deep Clone for immutability
        newSteps[stepIndex].completed = true;
        this.steps = newSteps;

        // Open the modal and pass the content
        this.isModalOpen = true;
        const modalComponent = this.template.querySelector("c-modal");
        if (modalComponent) {
            console.log("Modal component found");
            modalComponent.loadContent(
                newSteps[stepIndex].content,
                !!newSteps[stepIndex].content
            );
        } else {
            console.log("Modal component not found");
        }
    }

    // Decode URL for modal iframe
    get decodedModalContent() {
        console.log(this.currentModalContent);
        return decodeURI(this.currentModalContent);
    }

    // Handler function to close the modal component
    handleClose() {
        // Close the modal
        this.isModalOpen = false;
    }
}
