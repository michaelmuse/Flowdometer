// flowdometerInstructions.test.js

import { createElement } from 'lwc';
import FlowdometerInstructions from 'c/flowdometerInstructions';
// import MockedModal from './modal.mock.js';  // Import your mock

let element;  // Declare it once here at the top

jest.mock('c/modal', () => {
  const { LightningElement } = jest.requireActual('lwc');
  return {
    __esModule: true,
    default: class MockedModal extends LightningElement {
      name = 'mockedModal';
      slots = { content: [] };
      addEventListener = jest.fn((event, callback) => {
        if (event === 'close') {
          callback();
        }
      });
    },
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

  it('should render the correct number of steps', () => {
    return Promise.resolve().then(() => {
      const listItemEls = element.shadowRoot.querySelectorAll('li');
      expect(listItemEls.length).toBe(element.steps.length);
    });
  });

  it('should mark the first step as completed when clicked', () => {
    return Promise.resolve().then(() => {
      const listItemEls = element.shadowRoot.querySelectorAll('li');
      listItemEls[0].click();
      expect(element.steps[0].completed).toBe(true);
    });
  });
});