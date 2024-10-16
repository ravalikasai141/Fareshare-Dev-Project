public without sharing class ContactConsentController {
    @AuraEnabled(Cacheable=true)
    public static String getContactConsents(String recordId){
        try {
            Account con = [SELECT Id, PersonIndividualId FROM Account WHERE Id = :recordId];
            Boolean hasConsents = false;
            Map<String, ContactPointTypeConsent> contactPointTypeConsentMap = new Map<String, ContactPointTypeConsent>();
            for(ContactPointTypeConsent consent : [SELECT Id, DataUsePurposeId, DataUsePurpose.Name, DataUsePurpose.Consent_Family__c, Legal_Basis__c, PrivacyConsentStatus, Channel__c FROM ContactPointTypeConsent WHERE PartyId = :con.PersonIndividualId AND DataUsePurpose.Is_Active__c = true]) {
                contactPointTypeConsentMap.put(consent.DataUsePurpose.Consent_Family__c + '~' + consent.DataUsePurpose.Name + '~' + consent.Channel__c, consent);
                hasConsents = true;
            }

            List<String> channelValues = new List<String>();
            for(Schema.PicklistEntry ple : ContactPointTypeConsent.Channel__c.getDescribe().getPicklistValues()) {
                channelValues.add(ple.getLabel());
            }

            Map<String, List<ContactPointTypeConsentWrapper>> contactPointTypeConsentWrapperByPref = new Map<String, List<ContactPointTypeConsentWrapper>>();
            for(DataUsePurpose purpose : [SELECT Id, Name, Consent_Family__c FROM DataUsePurpose WHERE Is_Active__c = true ORDER BY Consent_Family__c, Name]) {
                List<ContactConsent> contactConsents = new List<ContactConsent>();
                for(String channel : channelValues) {
                    String consentKey = purpose.Consent_Family__c + '~' + purpose.Name + '~' + channel;
                    ContactConsent conConsent;
                    String key = purpose.Consent_Family__c + '~' + purpose.Name + '~' + channel;
                    if(contactPointTypeConsentMap.containsKey(consentKey)) {
                        ContactPointTypeConsent consentRecord = contactPointTypeConsentMap.get(consentKey);
                        conConsent = new ContactConsent(false, consentRecord.Id, consentRecord.Legal_Basis__c, channel, consentRecord.PrivacyConsentStatus, key, purpose.Consent_Family__c);
                    }
                    else {
                        conConsent = new ContactConsent(true, '', '', channel, 'Unselected', key, purpose.Consent_Family__c);
                    }
                    contactConsents.add(conConsent);
                }
                ContactPointTypeConsentWrapper cpcw = new ContactPointTypeConsentWrapper(purpose.Name, purpose.Id, contactConsents);
                List<ContactPointTypeConsentWrapper> cpcws = contactPointTypeConsentWrapperByPref.containsKey(purpose.Consent_Family__c) ? contactPointTypeConsentWrapperByPref.get(purpose.Consent_Family__c) : new List<ContactPointTypeConsentWrapper>();
                cpcws.add(cpcw);
                contactPointTypeConsentWrapperByPref.put(purpose.Consent_Family__c, cpcws);
            }

            List<ContactPointTypeConsentByPreference> contactPointTypeConsentsByPreferences = new List<ContactPointTypeConsentByPreference>();
            for(String preference : contactPointTypeConsentWrapperByPref.keySet()) {
                List<Channel> channels = new List<Channel>();
                for(String c : channelValues) {
                    channels.add(new Channel(c, preference + '~' + c));
                }
                if(contactPointTypeConsentWrapperByPref.get(preference) != null && contactPointTypeConsentWrapperByPref.get(preference).size() > 0) {
                    ContactPointTypeConsentByPreference cpcp = new ContactPointTypeConsentByPreference(preference, channels, contactPointTypeConsentWrapperByPref.get(preference));
                    contactPointTypeConsentsByPreferences.add(cpcp);
                }
            }


            return JSON.serializePretty(new ContactConsentInfo(contactPointTypeConsentsByPreferences, hasConsents));
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static List<PicklistWrapper> getSourceOptions() {
        List<PicklistWrapper> options = new List<PicklistWrapper>();
        options.add(new PicklistWrapper('--None--', ''));
		for (Schema.PicklistEntry picklistEntry : ContactPointTypeConsent.Consent_Capture_Source__c.getDescribe().getPicklistValues())
		{
			if (picklistEntry.isActive())
			{
                options.add(new PicklistWrapper(picklistEntry.getLabel(), picklistEntry.getValue()));
			}
		}

		return options;
    }

    @AuraEnabled(Cacheable=true)
    public static String getContactConsentSummary(String request, String recordId){
        Account con = [SELECT Id, PersonEmail, PersonMailingAddress, PersonHomePhone, Phone, PersonIndividualId FROM Account WHERE Id = :recordId LIMIT 1];

        Individual indv = [SELECT Id, Name FROM Individual WHERE Id = :con.PersonIndividualId LIMIT 1];
        ContactConsentInfo conConsentInfo = (ContactConsentInfo) JSON.deserialize(request, ContactConsentInfo.class);
        List<ContactConsentSummary> resultList = new List<ContactConsentSummary>();
        Set<String> channels = new Set<String>();
        for(ContactPointTypeConsentByPreference pref : conConsentInfo.preferences) {
            List<PurposeSummaryInfo> purposeSummarries = new List<PurposeSummaryInfo>();
            Boolean isPrefChanged = false;
            for(ContactPointTypeConsentWrapper conPointTypeConsent : pref.contactPointTypeConsents) {
                String dataPurpose = conPointTypeConsent.dataUsePurpose;
                List<ContactPointTypeConsent> conConsents = new List<ContactPointTypeConsent>();
                List<PurposeSummaryInfo> tempPurposeSummarries = new List<PurposeSummaryInfo>();
                for(ContactConsent conConsent : conPointTypeConsent.contactConsents) {
                    if(conConsent.isChanged) {
                        if(conConsent.privacyConsentStatusNewValue == 'OptIn') {
                            channels.add(conConsent.channel);
                        }
                        isPrefChanged = true;
                        ContactPointTypeConsent record = new ContactPointTypeConsent(Channel__c = conConsent.channel, Legal_Basis__c = conConsent.legalBasis, PrivacyConsentStatus = conConsent.privacyConsentStatusNewValue);
                        if(String.isBlank(conConsent.recordId)) {
                            String recordName = indv.Name + ' - ' + conConsent.channel + ' - ' + conPointTypeConsent.dataUsePurpose;
                            record.Name = recordName.length() > 80 ? recordName.substring(0, 79) : recordName;
                            record.DataUsePurposeId = conPointTypeConsent.dataUsePurposeId;
                            record.PartyId = con.PersonIndividualId;
                        }
                        else {
                            record.Id = conConsent.recordId;
                        }
                        PurposeSummaryInfo purposeSummary = new PurposeSummaryInfo(dataPurpose, conPointTypeConsent.dataUsePurposeId, record);
                        tempPurposeSummarries.add(purposeSummary);
                        dataPurpose = '';
                    }
                }
                if(tempPurposeSummarries.size() > 0) {
                    tempPurposeSummarries[0].count = tempPurposeSummarries.size();
                    purposeSummarries.addAll(tempPurposeSummarries);
                }
            }
            if(purposeSummarries.size() > 0) {
                resultList.add(new ContactConsentSummary(pref.preference, purposeSummarries, isPrefChanged));
            }
        }
        if(resultList.size() > 0) {
            List<String> warnings = new List<String>();
            if(channels.contains('Email') && String.isBlank(con.PersonEmail)) {
                warnings.add('Email does not exist, please update this information');
            }
            if(channels.contains('Post') && con.PersonMailingAddress == null) {
                warnings.add('Mailing Address does not exist, please update this information');
            }
            if(channels.contains('Phone') && String.isBlank(con.PersonHomePhone) && String.isBlank(con.Phone)) {
                warnings.add('Landline / Mobile does not exist, please update this information');
            }
            if(channels.contains('SMS') && String.isBlank(con.Phone)) {
                warnings.add('Mobile does not exist, please update this information');
            }
            return JSON.serializePretty(new Summary(resultList, warnings));
        }
        return '';
    }

    @AuraEnabled
    public static String saveConsentRecords(String request, String recordId, String campaign, String source, Datetime effectiveDateFrom, String comments){
        Account con = [SELECT Id, PersonEmail, PersonMailingAddress, PersonHomePhone,Phone, PersonIndividualId, PersonContactId FROM Account WHERE Id = :recordId LIMIT 1];
        Individual indv = [SELECT Id, Name FROM Individual WHERE Id = :con.PersonIndividualId LIMIT 1];
        try {
            Set<Id> updatedIds = new Set<Id>();
            List<ContactPointTypeConsent> consentsToUpsert = new List<ContactPointTypeConsent>();
            if(String.isNotBlank(request)) {
                List<ContactConsentSummary> conConsentSummarries = (List<ContactConsentSummary>) JSON.deserialize(request, List<ContactConsentSummary>.class);
                for(ContactConsentSummary conConsentSummary : conConsentSummarries) {
                    for(PurposeSummaryInfo purposeSummary : conConsentSummary.purposeSummarries) {
                        purposeSummary.consent.Person_Account__c = recordId;
                        purposeSummary.consent.Contact__c = con.PersonContactId;
                        if(campaign != ''){
                         purposeSummary.consent.Campaign__c = campaign;
                        }
                        purposeSummary.consent.Comments__c = comments;
                         if(effectiveDateFrom == null) {
                           purposeSummary.consent.EffectiveFrom = Datetime.now();
                         }
                        else {
                        purposeSummary.consent.EffectiveFrom = DateTime.valueOf(effectiveDateFrom);
                       }
                        purposeSummary.consent.CaptureDate = Datetime.now();
                        purposeSummary.consent.CaptureSource = source;
                        purposeSummary.consent.Consent_Capture_Source__c = source;
                        if(purposeSummary.consent.Id != null) {
                            updatedIds.add(purposeSummary.consent.Id);
                        }
                        consentsToUpsert.add(purposeSummary.consent);
                    }
                }
            }
           

            if(consentsToUpsert.size() == 0) {
                for(ContactPointTypeConsent consent: [SELECT Id FROM ContactPointTypeConsent WHERE PartyId = :con.PersonIndividualId AND Id NOT IN :updatedIds]) {
                    if(campaign != ''){
                       consent.Campaign__c = campaign;
                    }                        
                     if(effectiveDateFrom == null) {
                       consent.EffectiveFrom = Datetime.now();}
                    else {
                    consent.EffectiveFrom = DateTime.valueOf(effectiveDateFrom);
                    }
                    consent.CaptureDate = Datetime.now();
                    consent.Consent_Capture_Source__c = source;
                    consent.CaptureSource = source;
                    consent.Comments__c = comments;
                    consentsToUpsert.add(consent);
                }
            }

            if(consentsToUpsert.size() > 0) {
                upsert consentsToUpsert;
            }
            return 'Success';
        } catch (Exception e) {
            throw new AuraHandledException(+e.getMessage());
        }
    }

    public class Summary {
        @AuraEnabled public List<ContactConsentSummary> contactConsentSummarries {get;set;}
        @AuraEnabled public List<String> warnings {get;set;}

        public Summary(List<ContactConsentSummary> contactConsentSummarries, List<String> warnings) {
            this.contactConsentSummarries = contactConsentSummarries;
            this.warnings = warnings;
        }
    }

    public class ContactConsentSummary {
        @AuraEnabled public String preference {get;set;}
        @AuraEnabled public List<PurposeSummaryInfo> purposeSummarries {get;set;}
        @AuraEnabled public Boolean isPrefChanged {get;set;}

        public ContactConsentSummary(String preference, List<PurposeSummaryInfo> purposeSummarries, Boolean isPrefChanged) {
            this.preference = preference;
            this.purposeSummarries = purposeSummarries;
            this.isPrefChanged = isPrefChanged;
        }
    }

    public class PurposeSummaryInfo {
        @AuraEnabled public String dataUsePurpose {get;set;}
        @AuraEnabled public String dataUsePurposeId {get;set;}
        @AuraEnabled public ContactPointTypeConsent consent {get;set;}
        @AuraEnabled public String privacyConsentStatus {get; set;}
        @AuraEnabled public Integer count {get; set;}

        public PurposeSummaryInfo(String dataUsePurpose, String dataUsePurposeId, ContactPointTypeConsent consent) {
            this.dataUsePurpose = dataUsePurpose;
            this.dataUsePurposeId = dataUsePurposeId;
            this.consent = consent;
            this.privacyConsentStatus = this.consent.PrivacyConsentStatus == 'OptIn' ? 'Opt In' : 'Opt Out';
            this.count = 1;
        }
    }

    public class ContactConsentInfo {
        @AuraEnabled public List<ContactPointTypeConsentByPreference> preferences {get;set;}
        @AuraEnabled public Boolean hasConsents {get;set;}
       

        public ContactConsentInfo(List<ContactPointTypeConsentByPreference> preferences, Boolean hasConsents) {
            this.preferences = preferences;
            this.hasConsents = hasConsents;
           
        }
    }

    public class PicklistWrapper {
        @AuraEnabled public String label {get; set;}
        @AuraEnabled public String value {get; set;}

        public PicklistWrapper(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    public class ContactPointTypeConsentByPreference {
        @AuraEnabled public String preference {get; set;}
        @AuraEnabled public List<Channel> channels {get;set;}
        @AuraEnabled public List<ContactPointTypeConsentWrapper> contactPointTypeConsents {get;set;}

        public ContactPointTypeConsentByPreference(String preference, List<Channel> channels, List<ContactPointTypeConsentWrapper> contactPointTypeConsents) {
            this.preference = preference;
            this.channels = channels;
            this.contactPointTypeConsents = contactPointTypeConsents;
        }
    }

    public class Channel{
        @AuraEnabled public String value {get; set;}
        @AuraEnabled public String key {get; set;}

        public Channel(String value, String key) {
            this.value = value;
            this.key = key;
        }
    }

    public class ContactPointTypeConsentWrapper {
        @AuraEnabled public String dataUsePurpose {get; set;}
        @AuraEnabled public String dataUsePurposeId {get; set;}
        @AuraEnabled public List<ContactConsent> contactConsents {get; set;}

        public ContactPointTypeConsentWrapper(String dataUsePurpose, String dataUsePurposeId, List<ContactConsent> contactConsents) {
            this.dataUsePurpose = dataUsePurpose;
            this.dataUsePurposeId = dataUsePurposeId;
            this.contactConsents = contactConsents;
        }
    }

    public class ContactConsent {
        @AuraEnabled public Boolean isNew {get; set;}
        @AuraEnabled public String recordId {get; set;}
        @AuraEnabled public String legalBasis {get; set;}
        @AuraEnabled public String channel {get; set;}
        @AuraEnabled public String privacyConsentStatusOldValue {get; set;}
        @AuraEnabled public String privacyConsentStatusNewValue {get; set;}
        @AuraEnabled public String privacyConsentStatus {get; set;}
        @AuraEnabled public String key {get; set;}
        @AuraEnabled public Boolean isChanged {get; set;}
        @AuraEnabled public String purposeFamily {get; set;}

        public ContactConsent(Boolean isNew, String recordId, String legalBasis, String channel, String privacyConsentStatusValue, String key, String purposeFamily) {
            this.isNew = isNew;
            this.recordId = recordId;
            this.legalBasis = legalBasis;
            this.channel = channel;
            this.privacyConsentStatusOldValue = privacyConsentStatusValue;
            this.privacyConsentStatusNewValue = privacyConsentStatusValue;
            this.privacyConsentStatus = this.privacyConsentStatusNewValue == 'OptIn' ? 'Opt In' : (this.privacyConsentStatusNewValue == 'OptOut' ? 'Opt Out' : this.privacyConsentStatusNewValue);
            this.key = key;
            this.isChanged = false;
            this.purposeFamily = purposeFamily;
        }
    }
}