//force-app/main/default/lwc/flowdometerInstructions/__tests__/flowdometerInstructions.test.js
import { createElement } from "lwc";
import FlowdometerInstructions from "c/flowdometerInstructions";

let element;

describe("c-flowdometer-instructions", () => {
    beforeEach(() => {
        // Create initial element
        element = createElement("c-flowdometer-instructions", {
            is: FlowdometerInstructions
        });
        document.body.appendChild(element);
    });

    afterEach(() => {
        element = null;
    });

    it("should render the correct number of steps", async () => {
        await Promise.resolve(); // Wait for any asynchronous DOM updates
        const listItemEls = element.shadowRoot.querySelectorAll("li");
        expect(listItemEls.length).toBe(element.getSteps().length);
    });

    it("should mark the first step as completed when clicked", async () => {
        const listItemEls = element.shadowRoot.querySelectorAll("li");
        listItemEls[0].click();

        // Force re-rendering to pick up changed tracked properties
        await Promise.resolve();

        // Assuming we make steps available for testing
        expect(element.getSteps()[0].completed).toBe(true);
    });
});
