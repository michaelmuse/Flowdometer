import { createElement } from 'lwc';
import FlowdometerInstructions from 'c/flowdometerInstructions';

jest.mock(
    'lwc/modal',
    () => {
      return { __esModule: true, default: jest.fn() };
    },
    { virtual: true }
);
  

describe('c-flowdometer-instructions', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    it('should render all steps correctly', () => {
        // Create the component
        const element = createElement('c-flowdometer-instructions', {
            is: FlowdometerInstructions
        });

        // Attach it to the document
        document.body.appendChild(element);

        return Promise.resolve().then(() => {
            // Query all list items in the shadow DOM
            const listItemEls = element.shadowRoot.querySelectorAll('li');
            
            // Verify we have the correct number of steps rendered
            expect(listItemEls.length).toBe(element.steps.length);
        });
    });

    it('should mark a step as completed', () => {
        // Create and attach the component
        const element = createElement('c-flowdometer-instructions', {
            is: FlowdometerInstructions
        });
        document.body.appendChild(element);

        return Promise.resolve().then(() => {
            // Mock user interaction
            const listItemEls = element.shadowRoot.querySelectorAll('li');
            listItemEls[0].click();
            
            // Validate if the first step was marked as completed
            expect(element.steps[0].completed).toBe(true);
        });
    });

    it('should handle the modal close event', () => {
        // Create and attach the component
        const element = createElement('c-flowdometer-instructions', {
            is: FlowdometerInstructions
        });
        document.body.appendChild(element);

        return Promise.resolve().then(() => {
            // Listen for 'close' event from modal
            const handler = jest.fn();
            element.addEventListener('close', handler);
    
            // Simulate the modal close event
            const modal = element.shadowRoot.querySelector('c-modal');
            modal.dispatchEvent(new CustomEvent('close'));
    
            // Validate if the event was caught and handled
            expect(handler).toHaveBeenCalled();
        });
    });
});
