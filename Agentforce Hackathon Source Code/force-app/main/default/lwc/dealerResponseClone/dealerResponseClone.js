import { LightningElement, api } from 'lwc';

/*
  Clone of dealerResponse LWC (identical behavior).
  Exposes a single @api `value` property. Template binds directly to `value`.
*/
export default class DealerResponseClone extends LightningElement {
  responseValueJson = {
  "responses": [
    {
      "dealerName": "Western Auto Hub",
      "dealerId": "001ak000024SVIUAA4",
      "assets": [
        {
          "availableSlots": [
            {
              "timeSlot": "10:00 AM - 11:00 AM",
              "slotId": "02iak0000025HS5AAM10:00 AM - 11:00 AM"
            },
            {
              "timeSlot": "11:00 AM - 12:00 PM",
              "slotId": "02iak0000025HS5AAM11:00 AM - 12:00 PM"
            },
            {
              "timeSlot": "12:00 PM - 01:00 PM",
              "slotId": "02iak0000025HS5AAM12:00 PM - 01:00 PM"
            },
            {
              "timeSlot": "01:00 PM - 02:00 PM",
              "slotId": "02iak0000025HS5AAM01:00 PM - 02:00 PM"
            },
            {
              "timeSlot": "02:00 PM - 03:00 PM",
              "slotId": "02iak0000025HS5AAM02:00 PM - 03:00 PM"
            },
            {
              "timeSlot": "03:00 PM - 04:00 PM",
              "slotId": "02iak0000025HS5AAM03:00 PM - 04:00 PM"
            },
            {
              "timeSlot": "04:00 PM - 05:00 PM",
              "slotId": "02iak0000025HS5AAM04:00 PM - 05:00 PM"
            },
            {
              "timeSlot": "05:00 PM - 06:00 PM",
              "slotId": "02iak0000025HS5AAM05:00 PM - 06:00 PM"
            }
          ],
          "assetName": "Mahindra BE 6",
          "assetId": "02iak0000025HS5AAM"
        }
      ]
    }
  ]
};

responseValue;  
connectedCallback() {
    // nothing special for now
    this.responseValueJson.responses.forEach(dealer => {
      dealer.assets.forEach(asset => {
          asset.availableSlots.forEach(slot => {
              // existing properties remain untouched
              slot.className = 'slot-pill';
              slot.isSelected = false;
          });
      });
  });
  
  // trigger reactivity
  this.responseValue = { ...this.responseValueJson };
  
  console.log('DealerResponseClone:', JSON.stringify(this.responseValue));
   
}

selectedSlotId;

handleSlotSelect(event) {
    const slotId = event.currentTarget.dataset.slotId;
    this.selectedSlotId = slotId;

    this.updateSlots();
}

updateSlots() {
  this.responseValue.responses.forEach(dealer => {
    dealer.assets.forEach(asset => {
        asset.availableSlots.forEach(slot => {
            // existing properties remain untouched
            if (slot.slotId === this.selectedSlotId) {
                    slot.className = 'slot-pill-selected';
                    slot.isSelected = true;
            } else {
                    slot.className = 'slot-pill';
                    slot.isSelected = false;
            }
        });
    });
});
this.responseValue = { ...this.responseValue };
}
}