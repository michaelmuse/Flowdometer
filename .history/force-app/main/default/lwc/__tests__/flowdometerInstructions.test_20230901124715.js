import { createElement } from "lwc";
import FlowdometerInstructions from "c/flowdometerInstructions";
const element = createElement("c-flowdometer-instructions", {
  is: FlowdometerInstructions
});

jest.mock(
  "c/modal",
  () => {
    return {
      __esModule: true,
      default: jest.fn().mockImplementation(() => {
        return {
          name: "mockedModal",
          // Mocking the named slot 'content'
          slots: {
            content: []
          },
          addEventListener: jest.fn((event, callback) => {
            if (event === "close") {
              callback();
            }
          })
        };
      })
    };
  },
  { virtual: true }
);

describe("c-flowdometer-instructions", () => {
  // Setup before each test
  beforeEach(() => {
    element = createElement("c-flowdometer-instructions", {
      is: FlowdometerInstructions
    });
    document.body.appendChild(element);
  });

  // Teardown after each test
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("should handle the modal close event", () => {
    return Promise.resolve().then(() => {
      // Listen for 'close' event from modal
      const handler = jest.fn();
      element.addEventListener("close", handler);

      // Simulate the modal close event
      const modal = element.shadowRoot.querySelector("c-modal");
      modal.dispatchEvent(new CustomEvent("close"));

      // Validate if the event was caught and handled
      expect(handler).toHaveBeenCalled();

      // Verify if the modal content slot received the content
      const modalContentSlot = modal.slots.content;
      expect(modalContentSlot).toContain(element.currentModalContent);
    });
  });

  it("should render all steps correctly", () => {
    return Promise.resolve().then(() => {
      // Query all list items in the shadow DOM
      const listItemEls = element.shadowRoot.querySelectorAll("li");

      // Verify we have the correct number of steps rendered
      expect(listItemEls.length).toBe(element.steps.length);
    });
  });

  it("should mark a step as completed", () => {
    return Promise.resolve().then(() => {
      // Mock user interaction
      const listItemEls = element.shadowRoot.querySelectorAll("li");
      listItemEls[0].click();

      // Validate if the first step was marked as completed
      expect(element.steps[0].completed).toBe(true);
    });
  });

  it("should handle the modal close event", () => {
    return Promise.resolve().then(() => {
      // Listen for 'close' event from modal
      const handler = jest.fn();
      element.addEventListener("close", handler);

      // Simulate the modal close event
      const modal = element.shadowRoot.querySelector("c-modal");
      modal.dispatchEvent(new CustomEvent("close"));

      // Validate if the event was caught and handled
      expect(handler).toHaveBeenCalled();
    });
  });
});
