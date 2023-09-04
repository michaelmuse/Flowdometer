// in __tests__/modal.test.js
import { createElement } from 'lwc';
import Modal from 'c/modal';

describe('c-modal', () => {
    it('should emit close event when closed', () => {
        const element = createElement('c-modal', { is: Modal });
        document.body.appendChild(element);
        
        const handler = jest.fn();
        element.addEventListener('close', handler);

        // Simulate whatever action causes the modal to close
        element.shadowRoot.querySelector('button.close').click();

        return Promise.resolve().then(() => {
            expect(handler).toHaveBeenCalled();
        });
    });
});