import { createElement } from 'lwc';
import FlowdometerInstructions from 'c/flowdometerInstructions';
import MockedModal from '../__mocks__/modal.mock.js';  // Import your mock

let element;

// Use the mock class here
jest.mock('c/modal', () => {
  return {
    __esModule: true,
    default: MockedModal,
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
