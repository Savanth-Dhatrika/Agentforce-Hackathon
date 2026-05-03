import { LightningElement, api } from 'lwc';

/*
  Simplified component: expose a single @api `value` property.
  The template will bind directly to `value` (e.g. value.dealers,
  value.dealers[].assets, value.dealers[].assets[].availableSlots).
*/

export default class DealerResponse extends LightningElement {
  // Expose a single API property named `value`.
  // Template should bind directly to `value`, e.g. value.dealers, value.dealers[].assets, etc.
  @api value;
  response = [];

  connectedCallback() {
    this.response = this.value;
    //console.log('DealerResponseFinal connectedCallback, value:', JSON.stringify(this.response));
  }

  /*response

  @api
  set value(item) {
    this.response = item;
  }

  get value() {
    return this.response;
  }*/
}