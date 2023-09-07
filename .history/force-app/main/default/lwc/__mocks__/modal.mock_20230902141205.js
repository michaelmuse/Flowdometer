// force-app/main/default/lwc/__tests__/modal.mock.js
import { LightningElement } from "lwc";

export default class MockedModal extends LightningElement {
  name = "mockedModal";
  slots = { content: [] };
  addEventListener = jest.fn((event, callback) => {
    if (event === "close") {
      callback();
    }
  });
}
