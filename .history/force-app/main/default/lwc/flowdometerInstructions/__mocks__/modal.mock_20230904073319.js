// force-app/main/default/lwc/flowdometerInstructions/__mocks__/modal.mock.js
import { LightningElement } from 'lwc';

export default class MockedModal extends LightningElement {
  name = 'mockedModal';
  slots = { content: [] };
  addEventListener = jest.fn((event, callback) => {
    if (event === 'close') {
      callback();
    }
  });
}