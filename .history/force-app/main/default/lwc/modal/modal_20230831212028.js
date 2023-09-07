import { LightningElement, api } from "lwc";

export default class Modal extends LightningElement {
  @api title;

  handleClose() {
    // Dispatch a 'close' event so the parent component can handle it
    this.dispatchEvent(new CustomEvent("close"));
  }
}
