//force-app/main/default/lwc/flowdometerInstructions/__mocks__/modal.js
// File & Directory: force-app/main/default/lwc/flowdometerInstructions/__mocks__/mockedModal.js

import { LightningElement, api, track } from "lwc";

export default class MockedModal extends LightningElement {
  @api title;
  @api publicPropertyExample;
  @track internalStateExample;

  // Capturing method calls and their arguments
  methodCalls = {};

  // No longer needed
  // name = 'mockedModal';
  // slots = { content: [] };

  handleClose() {
    // Dispatch a 'close' event so the parent component can handle it
    this.dispatchEvent(new CustomEvent("close"));
  }

  connectedCallback() {
    // Mock implementation of connected lifecycle hook
  }

  yourMethod(arg1, arg2) {
    // Capturing method calls and their arguments for tests
    this.methodCalls["yourMethod"] = this.methodCalls["yourMethod"] || [];
    this.methodCalls["yourMethod"].push({ arg1, arg2 });
  }

  get slots() {
    return this.querySelectorAll("slot");
  }

  addEventListener(event, callback) {
    if (event === "close") {
      callback();
    }
  }

  // Utility method to reset the mock state for tests
  resetMockState() {
    this.methodCalls = {};
    // Reset other internal states if needed
  }
}
