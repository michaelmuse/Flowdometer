// flowdometerInstructions.test.js

import { createElement } from "lwc";
import FlowdometerInstructions from "c/flowdometerInstructions";
import MockedModal from "./modal.mock.js"; // Import your mock

let element; // Declare it once here at the top

// Use the mock class here
jest.mock(
  "c/modal",
  () => {
    return {
      __esModule: true,
      default: MockedModal // Use the imported mock class
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

  it("should render the correct number of steps", () => {
    return Promise.resolve().then(() => {
      const listItemEls = element.shadowRoot.querySelectorAll("li");
      expect(listItemEls.length).toBe(element.steps.length);
    });
  });

  it("should mark the first step as completed when clicked", () => {
    return Promise.resolve().then(() => {
      const listItemEls = element.shadowRoot.querySelectorAll("li");
      listItemEls[0].click();
      expect(element.steps[0].completed).toBe(true);
    });
  });
});

//I am getting failures when I run "npm run test":
// > Flowdometer@1.0.0 test
// > npm run test:unit
// > Flowdometer@1.0.0 test:unit
// > sfdx-lwc-jest -- --config jest.config.js
//  FAIL  force-app/main/default/lwc/__tests__/modal.mock.js
//   ● Test suite failed to run
//     TypeError: Class extends value undefined is not a constructor or null
//       2 | import { LightningElement } from 'lwc';
//     > 4 | export default class MockedModal extends LightningElement {                                                                                ^
//       5 |   name = 'mockedModal';
//       6 |   slots = { content: [] };
//       7 |   addEventListener = jest.fn((event, callback) => {
//       at Object.LightningElement (force-app/main/default/lwc/__tests__/modal.mock.js:4:42)
//  FAIL  force-app/main/default/lwc/__tests__/modal.test.js
//   ● Test suite failed to run
//     TypeError: Class extends value undefined is not a constructor or null
//       2 | import { LightningElement, api, track } from 'lwc';
//     > 4 | export default class MockedModal extends LightningElement {
//       5 |   // Emulating public properties
//       6 |   @api publicPropertyExample;
//       at Object.LightningElement (force-app/main/default/lwc/__mocks__/modal.js:4:42)
//       at Object.require (force-app/main/default/lwc/__tests__/modal.test.js:3:1)
//  FAIL  force-app/main/default/lwc/__tests__/flowdometerInstructions.test.js
//   ● Test suite failed to run
//     ReferenceError: F:\Muse Operations Drive\Projects\Flowdometer\force-app\main\default\lwc\__tests__\flowdometerInstructions.test.js: The module factory of `jest.mock()` is not allowed to reference any out-of-scope variables.
//     Invalid variable access: _registerDecorators
//       11 |   return {
//       12 |     __esModule: true,
//     > 13 |     default: _registerDecorators(class MockedModal extends LightningElement {
//       14 |       constructor(...args) {
//       15 |         super(...args);
//       16 |         this.name = 'mockedModal';
// Test Suites: 3 failed, 3 total
// Ran all test suites.
// q: can you look at line 53-87 in flowdometerInstructions.js and tell me how to fix my code to make the tests pass?
// a: I think you need to add a mock for the modal component. I think you can do that by adding a file called modal.mock.js in the same directory as your test file.
// In that file, you can export a class that extends LightningElement. You can then import that mock in your test file and pass it to the jest.mock function. I think that should work.
// q: can you write code to apply the advice in line 89 of flowdometerInstructions.test.js, and let me know where to put the code and changes (file and directory)?
// a: I think you need to add a mock for the modal component. I think you can do that by adding a file called modal.mock.js in the same directory as your test file. In that file, you can export a class that extends LightningElement. You can then import that mock in your test file and pass it to the jest.mock function. I think that should work.
// q: I have a modal.mock.js file in the same directory as flowdometerInstructions.test.js, but I need you to check the code and suggest any changes to make the tests pass.
