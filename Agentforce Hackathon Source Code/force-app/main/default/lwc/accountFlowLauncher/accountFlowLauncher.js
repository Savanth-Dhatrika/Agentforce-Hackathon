import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class AccountFlowLauncher extends LightningElement {
    @api recordId;
    showFlow = true;
    isLoading = false;

    get inputVariables() {
        return [
            {
                name: 'recordId',
                type: 'String',
                value: this.recordId
            }
        ];
    }

    handleStatusChange(event) {
        const { status } = event.detail;
        
        if (status === 'FINISHED' || status === 'FINISHED_SCREEN') {
            this.dispatchEvent(new CloseActionScreenEvent());
        } else if (status === 'ERROR') {
            console.error('Flow error:', event.detail);
        }
    }
}