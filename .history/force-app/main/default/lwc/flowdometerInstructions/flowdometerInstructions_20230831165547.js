export default class FlowdometerInstructions extends LightningElement {
  // Define the array of steps for the Welcome Mat
  steps = [
    {
      label: "Tracking",
      description:
        "Next, set up listeners to track changes to fields over time here:",
      completed: false,
      content: "https://on.driveway.app/guides/bLekwqW/embed"
    },
    {
      label: "Goals / SLAs",
      description: "Last, set up your goals here:",
      completed: false,
      content: "https://on.driveway.app/guides/0LYOe0W/embed"
    },
    {
      label: "Extending Flowdometer",
      description:
        "Flowdometer is an open-source project that is designed to be built on top of. The Flow and Step objects can be added to with whatever fields are necessary for your use case.\n\n" +
        "Flowdometer data on my tracked record\n" +
        "For example, you might build an automation to have your tracked object point at the Flow Tracker record that is tracking it. This would allow you to then pull in the data from the Flow record, and Most Recent Step record, including goal attainment progress bars, and put them directly on the tracked object. Imagine sorting all your opportunities by Next Breach At.\n\n" +
        "Business Hours\n" +
        'Another example, Flowdometer doesn’t support business hours out of the box, but we’ve included another open source project from Unofficial SF that will allow you to calculate these times in Flow Builder. In Flow Builder, check out the flow template we made called "Flowdometer - Autocalculate Business Hours". In there, you\'ll see how you can use an Action (created by Professor Flow - thank you!) that will allow you to create whatever rules you have for different business hours in your company, and calculate them with this action.'
    }
  ];

  // Handler function to mark a step as completed
  handleStepCompleted(event) {
    const stepIndex = event.detail;
    this.steps[stepIndex].completed = true;
  }

  // Handler function to close the modal component
  handleClose() {
    // Added this method
    // Fire the custom event 'close' from this component
    const closeEvent = new CustomEvent("close");
    this.dispatchEvent(closeEvent);
  }
}
