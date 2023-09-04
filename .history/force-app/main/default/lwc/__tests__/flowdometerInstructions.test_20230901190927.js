import { createElement, LightningElement } from 'lwc';
import FlowdometerInstructions from 'c/flowdometerInstructions';

let element;  // Declare it once here at the top

jest.mock('c/modal', () => {
    return {
      __esModule: true,
      default: jest.fn().mockImplementation(() => {
        class MockedModal extends LightningElement {
          name = 'mockedModal';
          slots = { content: [] };
          addEventListener = jest.fn((event, callback) => {
            if (event === 'close') {
              callback();
            }
          });
        }
        return new MockedModal();
      }),
    };
}, { virtual: true });

describe('c-flowdometer-instructions', () => {
  beforeEach(() => {
        element = createElement('c-flowdometer-instructions', { is: FlowdometerInstructions });
        document.body.appendChild(element);
  });

  afterEach(() => {
      while (document.body.firstChild) {
          document.body.removeChild(document.body.firstChild);
      }
  });

  it('should render all steps correctly', () => {
    return Promise.resolve().then(() => {
      // Query all list items in the shadow DOM
      const listItemEls = element.shadowRoot.querySelectorAll('li');
      
      // Verify we have the correct number of steps rendered
      expect(listItemEls.length).toBe(element.steps.length);
  });
});

  it('should render the correct number of steps', () => {  // Updated test name
    return Promise.resolve().then(() => {
      const listItemEls = element.shadowRoot.querySelectorAll('li');
      expect(listItemEls.length).toBe(element.steps.length);
    });
  });

  it('should mark the first step as completed when clicked', () => {  // Updated test name
    return Promise.resolve().then(() => {
      const listItemEls = element.shadowRoot.querySelectorAll('li');
      listItemEls[0].click();
      expect(element.steps[0].completed).toBe(true);
    });
  });
});

// q: can you look through this code for bugs and tell me what you think?
// a: I think the test for the modal close event is wrong.  The modal is not a child of the flowdometerInstructions component, so it can't dispatch an event to it.  The test should be for the modal component.