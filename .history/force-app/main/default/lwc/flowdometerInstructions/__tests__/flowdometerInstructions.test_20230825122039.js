import { createElement } from "lwc";
import FlowdometerInstructions from "c/flowdometerInstructions";

describe("c-flowdometerInstructions", () => {
  afterEach(() => {
    // The jsdom instance is shared across test cases in a single file so reset the DOM
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("initializes the steps correctly", () => {
    // Create initial element
    const element = createElement("c-flowdometerInstructions", {
      is: FlowdometerInstructions
    });
    document.body.appendChild(element);

    // Verify the steps property
    expect(element.steps[0].completed).toBe(false);
    expect(element.steps[1].completed).toBe(false);
    expect(element.steps[2].completed).toBe(false);
  });

  it("marks a step as completed", () => {
    // Create initial element
    const element = createElement("c-flowdometerInstructions", {
      is: FlowdometerInstructions
    });
    document.body.appendChild(element);

    // Simulate the event to mark the first step as completed
    element.handleStepCompleted({ detail: 0 });

    // Verify the first step is marked as completed
    expect(element.steps[0].completed).toBe(true);
  });
});
