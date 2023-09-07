import { createElement, LightningElement } from "lwc";
import FlowdometerInstructions from "c/flowdometerInstructions";

let element; // Declare it once here at the top

jest.mock(
  "c/modal",
  () => {
    return {
      __esModule: true,
      default: jest.fn().mockImplementation(() => {
        class MockedModal extends LightningElement {
          name = "mockedModal";
          slots = { content: [] };
          addEventListener = jest.fn((event, callback) => {
            if (event === "close") {
              callback();
            }
          });
        }
        return new MockedModal();
      })
    };
  },
  { virtual: true }
);

describe("c-flowdometer-instructions", () => {
  beforeEach(() => {
    element = createElement("c-flowdometer-instructions", {
      is: FlowdometerInstructions
    });
    document.body.appendChild(element);
  });

  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
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

  it("should handle the modal close event correctly", () => {
    // Renamed the test
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
