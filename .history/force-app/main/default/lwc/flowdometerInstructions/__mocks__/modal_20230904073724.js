//force-app/main/default/lwc/flowdometerInstructions/__mocks__/modal.js
import { LightningElement, api, track } from "lwc";

export default class MockedModal extends LightningElement {
  // Emulating public properties
  @api publicPropertyExample;

  // To keep track of internal state if needed, like slots or other variables
  @track internalStateExample;

  // To capture method calls and their arguments
  methodCalls = {};

  connectedCallback() {
    // Mock implementation of connected lifecycle hook if needed
    // You can trigger some default behavior here if you'd like.
  }

  yourMethod(arg1, arg2) {
    // Capturing method calls and their arguments for assertion during tests
    this.methodCalls["yourMethod"] = this.methodCalls["yourMethod"] || [];
    this.methodCalls["yourMethod"].push({ arg1, arg2 });

    // Mock the original behavior if needed.
  }

  // If your component has slots, you can mock that as well here
  get slots() {
    return this.querySelectorAll("slot");
  }

  // Add more mock functionality as needed

  // Utility method to reset the mock state if you need to clean between tests
  resetMockState() {
    this.methodCalls = {};
    // Reset other internal states if needed
  }

  name = "mockedModal";
  slots = { content: [] };
  addEventListener = jest.fn((event, callback) => {
    if (event === "close") {
      callback();
    }
  });
}
