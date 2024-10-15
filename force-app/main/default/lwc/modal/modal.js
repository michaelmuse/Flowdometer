//force-app/main/default/lwc/modal/modal.js
import { LightningElement, api, track } from "lwc";

export default class Modal extends LightningElement {
    @api title;
    @api currentModalContent = ""; // Existing property for content
    @track currentModalContentIsIframe = true; // New property to track if the content is an iframe
    @track internalStateExample;
    @api

    // New method to handle the iframe load event
    loadContent(content, isIframe) {
        console.log("loadContent called", content, isIframe);
        this.currentModalContent = content ? encodeURI(content) : "";
        this.currentModalContentIsIframe = isIframe;
    }

    // Capturing method calls and their arguments
    methodCalls = {};

    handleClose() {
        // Dispatch a 'close' event so the parent component can handle it
        this.dispatchEvent(new CustomEvent("close"));
    }

    connectedCallback() {
        // Mock implementation of connected lifecycle hook
        // Add logic if necessary
    }

    yourMethod(arg1, arg2) {
        // Capturing method calls and their arguments for tests
        this.methodCalls["yourMethod"] = this.methodCalls["yourMethod"] || [];
        this.methodCalls["yourMethod"].push({ arg1, arg2 });
    }

    addEventListener(event, callback) {
        // A more flexible approach to handle different events
        this.methodCalls[event] = this.methodCalls[event] || [];
        this.methodCalls[event].push(callback);
    }

    // Utility method to reset the mock state for tests
    resetMockState() {
        this.methodCalls = {};
        // Reset other internal states if needed
    }
}
