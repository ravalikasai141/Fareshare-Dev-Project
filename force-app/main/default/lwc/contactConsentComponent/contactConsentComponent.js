import { LightningElement, api, track, wire } from "lwc";
import { NavigationMixin } from 'lightning/navigation';

import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getContactConsents from "@salesforce/apex/ContactConsentController.getContactConsents";
import getContactConsentSummary from "@salesforce/apex/ContactConsentController.getContactConsentSummary";
import saveConsentRecords from "@salesforce/apex/ContactConsentController.saveConsentRecords";

export default class ContactConsentComponent extends NavigationMixin(LightningElement) { 
    @api recId;
    @track contactConsentData;
    dateval;
  
    contactConsentDataOriginal;
    sourceOptions;
    comments;
    campaignValue;
    sourceValue;
    effectiveDateFrom;
    showOtherField = false;
    wiredContactConsent;
    consents;
    preferences;
    contactPointTypeConsents;
    contactConsentSummarries;
    warnings;
    showSummary = false;
    @api isLoading = false;
    disableNext = true;
    showWarningMessage = false;
    @track
    status = [
        {
            id: 'menu-item-1',
            label: 'Opt In',
            value: 'OptIn',
        },
        {
            id: 'menu-item-2',
            label: 'Opt Out',
            value: 'OptOut',
        }
    ];
    connectedCallback(){
       var currentdate=new Date(new Date().toISOString());
        this.dateval=currentdate.toISOString();
    }
    @wire(getContactConsents, { recordId: '$recId'})
    contactConsents(result) {
        this.wiredContactConsent = result;
        if (result.data) {
            this.contactConsentData = JSON.parse(result.data);
            this.disableNext = !this.contactConsentData.hasConsents;
          //  this.sourceOptions = this.contactConsentData.sourceOptions;
            this.contactConsentDataOriginal = JSON.parse(result.data);
           
            this.error = undefined;
            this.isLoading = false;
        } else if (result.error) {
            this.error = 'Unknown error';
            if (Array.isArray(result.error.body)) {
                this.error = result.error.body.map(e => e.message).join(', ');
            } else if (typeof result.error.body.message === 'string') {
                this.error = result.error.body.message;
            }
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: this.error,
                    variant: 'error'
                }),
            );
            this.dispatchEvent(new CustomEvent('closequickaction'));
            this.contactConsentData = undefined;
            this.isLoading = false;
        }
    }

    reset() {
        return refreshApex(this.wiredContactConsent);
    }

    navigateToPurpose(event) {
        this[NavigationMixin.GenerateUrl]({
            type: 'standard__recordPage',
            attributes: {
                recordId:event.target.dataset.targetId,
                actionName: 'view',
            },
        }).then(url => {
             window.open(url); 
        });
    }

    handlePurpose(event) {
        this.getPreferences(event.target.dataset.targetId);
        for(let i = 0; i < this.preferences[0].contactPointTypeConsents.length; i++) {
            let contactPointTypeConsent = this.preferences[0].contactPointTypeConsents[i];
            for(let j = 0; j < contactPointTypeConsent.contactConsents.length; j++) {
                let consent = contactPointTypeConsent.contactConsents[j];
                this.setConsent(consent, event.detail.value);
            }
        }
        this.disableNext = !(this.contactConsentData.hasConsents || this.isChanged());
        console.log(this.contactConsentData.preferences);
    }

    handleChannel(event) {
        let keys = event.target.dataset.targetId.split("~");
        this.getPreferences(keys[0]);
        console.log(this.preferences);
        for(let i = 0; i < this.preferences[0].contactPointTypeConsents.length; i++) {
            let contactPointTypeConsent = this.preferences[0].contactPointTypeConsents[i];
            let contactConsentArray = contactPointTypeConsent.contactConsents.filter(y => {
                return y.channel === keys[1]
            });
            for(let j = 0; j < contactConsentArray.length; j++) {
                let consent = contactConsentArray[j];
                this.setConsent(consent, event.detail.value);
            }
        }
        this.disableNext = !(this.contactConsentData.hasConsents || this.isChanged());
        console.log(this.contactConsentData.preferences);
    }

    handleIndividualPurpose(event) {
        let dataPurposeId = event.target.dataset.targetId;
        
        for(let i = 0; i < this.contactConsentData.preferences.length; i++) {
            for(let j = 0; j < this.contactConsentData.preferences[i].contactPointTypeConsents.length; j++) {
                console.log(this.contactConsentData.preferences[i].contactPointTypeConsents[j]);
                if(this.contactConsentData.preferences[i].contactPointTypeConsents[j].dataUsePurposeId === dataPurposeId) {
                    let contactConsents = this.contactConsentData.preferences[i].contactPointTypeConsents[j].contactConsents;
                    for(let k = 0; k < this.contactConsentData.preferences[i].contactPointTypeConsents[j].contactConsents.length; k++) {
                        this.setConsent(this.contactConsentData.preferences[i].contactPointTypeConsents[j].contactConsents[k], event.detail.value);
                    }
                    break;
                }
            }
        }
        this.disableNext = !(this.contactConsentData.hasConsents || this.isChanged());
    }

    handlePreference(event) {
     
        this.getConsents(event.target.dataset.targetId);
        this.setConsent(this.consents[0], event.detail.value);
        this.disableNext = !(this.contactConsentData.hasConsents || this.isChanged());
        
    }

    undoPreference(event) {
        this.getConsents(event.target.dataset.targetId);
        this.consents[0].privacyConsentStatusNewValue = this.consents[0].privacyConsentStatusOldValue;
        this.consents[0].privacyConsentStatus = this.consents[0].privacyConsentStatusOldValue == 'OptIn' ? 'Opt In' : (this.consents[0].privacyConsentStatusOldValue == 'OptOut' ? 'Opt Out' : this.consents[0].privacyConsentStatusOldValue);
       
        this.consents[0].legalBasis = 'Consent';
        if(this.consents[0].purposeFamily === 'Product') {
            this.consents[0].legalBasis = 'Contract';
        }
        if(this.consents[0].privacyConsentStatusNewValue === 'Unselected') {
            this.consents[0].legalBasis = '';
        }
        if(this.consents[0].privacyConsentStatusNewValue === 'Seen') {
            this.consents[0].legalBasis = 'Legitimate Interest';
        }
        this.consents[0].isChanged = false;
     
        this.disableNext = !(this.contactConsentData.hasConsents || this.isChanged());
    }

    getConsents(key) {
        let keys = key.split("~");
        this.getPreferences(keys[0]);
        this.getContactPointTypeConsents(keys[1]);
        this.consents = this.contactPointTypeConsents[0].contactConsents.filter(y => {
            return y.channel === keys[2]
        });
    }

    getPreferences(key) {
        this.preferences = this.contactConsentData.preferences.filter(y => {
            return y.preference === key
        });
    }

    getContactPointTypeConsents(key) {
        this.contactPointTypeConsents = this.preferences[0].contactPointTypeConsents.filter(y => {
            return y.dataUsePurpose === key
        });
    }

    setConsent(consent, value) {
        if(consent.isPreferenceSelectionDisabled) {
            return;
        }
        consent.privacyConsentStatusNewValue = value;
        consent.privacyConsentStatus = value == 'OptIn' ? 'Opt In' : (value == 'OptOut' ? 'Opt Out' : value);
        consent.legalBasis = 'Consent';
        if(consent.purposeFamily === 'Product') {
            consent.legalBasis = 'Contract';
        }
        if(consent.privacyConsentStatusNewValue === 'Unselected') {
            consent.legalBasis = '';
        }
        if(consent.privacyConsentStatusNewValue === 'Seen') {
            consent.legalBasis = 'Legitimate Interest';
        }
        consent.isChanged = false;
        if(consent.privacyConsentStatusNewValue !== consent.privacyConsentStatusOldValue) {
            consent.isChanged = true;
        }
    }

    handleNext(event) {
  
        this.isLoading = true;
        getContactConsentSummary({ request: JSON.stringify(this.contactConsentData), recordId: this.recId })
		.then(result => {
            this.showSummary = true;
            if(result === '') {
                this.showWarningMessage = true;
            }
            const summary = JSON.parse(result);
            this.contactConsentSummarries = summary.contactConsentSummarries;
            this.warnings = summary.warnings;
            this.isLoading = false;
		})
		.catch(error => {
			this.error = error;
            this.isLoading = false;
		})
    }

    handleCancel(event) {
        this.dispatchEvent(new CustomEvent('closequickaction'));
    }

    handleReset(event) {
        this.isLoading = true;
        for(let i = 0; i < this.contactConsentData.preferences.length; i++) {
            let preference = this.contactConsentData.preferences[i];
            for(let j = 0; j < preference.contactPointTypeConsents.length; j++) {
                let contactPointTypeConsent = preference.contactPointTypeConsents[j];
                for(let k = 0; k < contactPointTypeConsent.contactConsents.length; k++) {
                    let consent = contactPointTypeConsent.contactConsents[k];
                    this.setConsent(consent, consent.privacyConsentStatusOldValue);
                }
            }
        }
        this.isLoading = false;
        this.disableNext = !(this.contactConsentData.hasConsents || this.isChanged());
    }

    handleSave(event) {
          if(this.sourceValue == null || this.sourceValue == '') {
            const evt = new ShowToastEvent({
                title: "Error",
                message: "Please enter the Source",
                variant: "error",
                mode: "sticky"
            });
            this.dispatchEvent(evt);
            return;
          }
        this.isLoading = true;
        saveConsentRecords({ 
            request: JSON.stringify(this.contactConsentSummarries), 
            recordId: this.recId,
            campaign: this.campaignValue,
            effectiveDateFrom: this.effectiveDateFrom,
            source: this.sourceValue,
            comments: this.comments
        })
		.then(result => {
            if(result === 'Success') {
                const evt = new ShowToastEvent({
                    title: "Success",
                    message: "Consents are Successfully Saved",
                    variant: "success",
                    mode: "pester"
                });
                this.dispatchEvent(evt);
                this.dispatchEvent(new CustomEvent('closequickaction'));
                this[NavigationMixin.GenerateUrl]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: this.recId,
                        actionName: 'view',
                    },
                }).then(url => {
                     window.open(url, '_self');
                });
            }
		})
		.catch(error => {
			this.error = error;
             const evt = new ShowToastEvent({
                title: "Error",
                 message: "Error in JS",
                 variant: "error",
                mode: "sticky"
            });
             this.dispatchEvent(evt);
            
		})
        this.isLoading = false;
    }

    isChanged() {
        for(let i = 0; i < this.contactConsentData.preferences.length; i++) {
            let preference = this.contactConsentData.preferences[i];
            for(let j = 0; j < preference.contactPointTypeConsents.length; j++) {
                let contactPointTypeConsent = preference.contactPointTypeConsents[j];
                for(let k = 0; k < contactPointTypeConsent.contactConsents.length; k++) {
                    let consent = contactPointTypeConsent.contactConsents[k];
                    if(consent.isChanged) {
                        return true;
                    }
                }
            }
        }
        return false;
    }

    handleBack(event) {
        this.showSummary = false;
        this.contactConsentSummarries = null;
        this.showWarningMessage = false;
    }
    handleCampaignField(event) {
       
        this.campaignValue = event.target.value;
    }
    handleEffectiveDateChange(event) {
        this.effectiveDateFrom = event.target.value;
       
    }
    handleSourceField(event) {
        
        this.sourceValue = event.target.value;
       
    }
    handleCommentsField(event) {
        this.comments = event.target.value;
       
    }
    
}