// __mocks__/modal.js
import { LightningElement, api } from 'lwc';

export default class MockedModal extends LightningElement {
  // Define your public properties and methods for the mock
  @api publicPropertyExample;
  
  connectedCallback() {
    // Mock implementation of connected lifecycle hook if needed
  }
  
  yourMethod() {
    // Mock methods here
  }
  
  // Add more mock functionality as needed
}