//force-app/main/default/lwc/__tests__/flowdometerInstructions.test.js
import { createElement } from 'lwc';
import FlowdometerInstructions from 'c/flowdometerInstructions';

describe('c-flowdometer-instructions', () => {
  let element;
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
    const listItemEls = element.shadowRoot.querySelectorAll('li');
    expect(listItemEls.length).toBe(element.steps.length);
  });

  it('should mark the first step as completed when clicked', async () => {
    const listItemEls = element.shadowRoot.querySelectorAll('li');
    listItemEls[0].click();

    // Force re-rendering to pick up changed tracked properties
    await Promise.resolve();

    // Assuming we make steps available for testing
    expect(element.getSteps()[0].completed).toBe(true);
  });
});