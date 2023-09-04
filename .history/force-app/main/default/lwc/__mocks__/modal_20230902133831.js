// __mocks__/modal.js
import { LightningElement, api, track } from 'lwc';

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
    this.methodCalls['yourMethod'] = this.methodCalls['yourMethod'] || [];
    this.methodCalls['yourMethod'].push({ arg1, arg2 });

    // Mock the original behavior if needed.
  }
  
  // If your component has slots, you can mock that as well here
  get slots() {
    return this.querySelectorAll('slot');
  }

  // Add more mock functionality as needed

  // Utility method to reset the mock state if you need to clean between tests
  resetMockState() {
    this.methodCalls = {};
    // Reset other internal states if needed
  }
}
Here's a breakdown of what we are doing:

@api publicPropertyExample: This will emulate any public properties your real component has.

@track internalStateExample: This is a tracked private property you can use to emulate any internal state your component might maintain.

methodCalls: This is a plain JavaScript object that captures the history of method calls made to this mock. You can use this for assertions in your tests.

yourMethod(arg1, arg2): This function emulates a method in your actual component. I've added logic to capture method calls and their arguments.

get slots(): If your component uses slots, this getter will help you mimic that functionality.

resetMockState(): A utility method you can call in afterEach or beforeEach


