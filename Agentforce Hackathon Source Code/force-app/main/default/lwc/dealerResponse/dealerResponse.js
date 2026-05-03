import { LightningElement, api, track } from 'lwc';

/*
  Simplified component: expose a single @api `value` property.
  The template will bind directly to `value` (e.g. value.dealers,
  value.dealers[].assets, value.dealers[].assets[].availableSlots).
*/

export default class DealerResponse extends LightningElement {
  // Expose a single API property named `value`.
  // Template should bind directly to `value`, e.g. value.dealers, value.dealers[].assets, etc.
  @api value;
  @track dealerResponse = [];
  connectedCallback() {
    const dealerResponse = this.value?.DealerResponse;
    this.dealerResponse = [...dealerResponse];
  }
}