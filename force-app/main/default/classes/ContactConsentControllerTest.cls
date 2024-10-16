@isTest
public with sharing class ContactConsentControllerTest {
    @testSetup static void setup(){
        // Account acc = new Account(Name = 'test account');
        // insert acc;

        Individual ind = new Individual(FirstName = 'test', LastName = 'contact');
        insert ind;

        Contact con = new Contact(FirstName = 'test', LastName = 'contact', Email = 'test@contact.com', IndividualId = ind.Id);
        insert con;

        Id accRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();



        Account acc = new Account(FirstName = 'Test', LastName = 'person account', RecordTypeId = accRecordTypeId);
        insert acc;

        DataUsePurpose dp1 = new DataUsePurpose(Name = 'Volunteering', Consent_Family__c = 'Marketing', Is_Active__c = true);
        DataUsePurpose dp2 = new DataUsePurpose(Name = 'Membership', Consent_Family__c = 'Marketing', Is_Active__c = true);
        DataUsePurpose dp3 = new DataUsePurpose(Name = 'Prevention', Consent_Family__c = 'Activities', Is_Active__c = true);
        insert new List<DataUsePurpose>{dp1, dp2, dp3};

        Campaign camp = new Campaign(Name = 'TestCampaign', IsActive = true);
        insert camp;
    }

    @isTest
    public static void itShouldReturnResponseWithoutPreferencePrepopulated() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];

        Account acc = [SELECT Id,PersonContactId FROM Account LIMIT 1];

        String response = ContactConsentController.getContactConsents(acc.Id);
        system.assert(String.isNotBlank(response));

        ContactConsentController.ContactConsentInfo conConsentInfo = (ContactConsentController.ContactConsentInfo) JSON.deserialize(response, ContactConsentController.ContactConsentInfo.class);

        system.assertEquals(false, conConsentInfo.hasConsents);
        system.assertEquals(2, conConsentInfo.preferences.size());
    }

    @isTest
    public static void itShouldReturnResponseWithPreferencePrepopulated() {
       // Contact con = [SELECT Id, IndividualId FROM Contact LIMIT 1];
        Campaign camp = [SELECT Id, Name FROM Campaign WHERE IsActive = true LIMIT 1];
        Account acc = [SELECT Id, PersonContactId, PersonIndividualId FROM Account LIMIT 1];

        DataUsePurpose volunteering = [SELECT Id FROM DataUsePurpose WHERE Name = 'Volunteering'];
        DataUsePurpose membership = [SELECT Id FROM DataUsePurpose WHERE Name = 'Membership'];
        DataUsePurpose prevention = [SELECT Id FROM DataUsePurpose WHERE Name = 'Prevention'];

        ContactPointTypeConsent contactConsent1 = new ContactPointTypeConsent(Name = 'Consent 1', PartyId = acc.PersonIndividualId, DataUsePurposeId = volunteering.Id, Legal_Basis__c = 'Consent', PrivacyConsentStatus = 'OptIn', Channel__c = 'Email',Contact__c = acc.PersonContactId, Person_Account__c = acc.Id, Campaign__c = camp.Id);
        ContactPointTypeConsent contactConsent2 = new ContactPointTypeConsent(Name = 'Consent 2', PartyId = acc.PersonIndividualId, DataUsePurposeId = volunteering.Id, Legal_Basis__c = 'Consent', PrivacyConsentStatus = 'OptIn', Channel__c = 'Post',Contact__c = acc.PersonContactId, Person_Account__c = acc.Id, Campaign__c = camp.Id);
        ContactPointTypeConsent contactConsent3 = new ContactPointTypeConsent(Name = 'Consent 3', PartyId = acc.PersonIndividualId, DataUsePurposeId = prevention.Id, Legal_Basis__c = 'Consent', PrivacyConsentStatus = 'OptOut', Channel__c = 'Email',Contact__c = acc.PersonContactId, Person_Account__c = acc.Id, Campaign__c = camp.Id);
        insert new List<ContactPointTypeConsent>{contactConsent1, contactConsent2, contactConsent3};

        String response = ContactConsentController.getContactConsents(acc.Id);
        system.assert(String.isNotBlank(response));

        ContactConsentController.ContactConsentInfo conConsentInfo = (ContactConsentController.ContactConsentInfo) JSON.deserialize(response, ContactConsentController.ContactConsentInfo.class);

        system.assertEquals(true, conConsentInfo.hasConsents);
        system.assertEquals(2, conConsentInfo.preferences.size());
    }

    @isTest
    public static void itShouldGetConsentSummaryAndSaveRecord() {
        //Contact con = [SELECT Id, IndividualId FROM Contact LIMIT 1];
        Campaign camp = [SELECT Id,Name FROM Campaign WHERE IsActive = true LIMIT 1];
        Account acc = [SELECT Id, PersonContactId, PersonIndividualId FROM Account LIMIT 1];

        DataUsePurpose volunteering = [SELECT Id FROM DataUsePurpose WHERE Name = 'Volunteering'];
        DataUsePurpose membership = [SELECT Id FROM DataUsePurpose WHERE Name = 'Membership'];
        DataUsePurpose prevention = [SELECT Id FROM DataUsePurpose WHERE Name = 'Prevention'];

        ContactPointTypeConsent contactConsent1 = new ContactPointTypeConsent(Name = 'Consent 1', PartyId = acc.PersonIndividualId, DataUsePurposeId = volunteering.Id, Legal_Basis__c = 'Consent', PrivacyConsentStatus = 'OptIn', Channel__c = 'Email', Contact__c = acc.PersonContactId, Person_Account__c = acc.Id, Campaign__c = camp.Id);
        ContactPointTypeConsent contactConsent2 = new ContactPointTypeConsent(Name = 'Consent 2', PartyId = acc.PersonIndividualId, DataUsePurposeId = volunteering.Id, Legal_Basis__c = 'Consent', PrivacyConsentStatus = 'OptIn', Channel__c = 'SMS', Contact__c = acc.PersonContactId, Person_Account__c = acc.Id, Campaign__c = camp.Id);
        insert new List<ContactPointTypeConsent>{contactConsent1, contactConsent2};

        String response = ContactConsentController.getContactConsents(acc.Id);

        ContactConsentController.ContactConsentInfo conConsentInfo = (ContactConsentController.ContactConsentInfo) JSON.deserialize(response, ContactConsentController.ContactConsentInfo.class);
        ContactConsentController.ContactPointTypeConsentByPreference marketingPref = conConsentInfo.preferences[0];
        ContactConsentController.ContactPointTypeConsentWrapper membershipPurpose = marketingPref.contactPointTypeConsents[0];
        ContactConsentController.ContactConsent membershipPostConsent = membershipPurpose.contactConsents[0];
        membershipPostConsent.channel = 'Post';
        membershipPostConsent.isChanged = true;
        membershipPostConsent.privacyConsentStatusOldValue = 'Unselected';
        membershipPostConsent.privacyConsentStatusNewValue = 'OptIn';
        membershipPostConsent.legalBasis = 'Consent';
        ContactConsentController.ContactConsent membershipEmailConsent = membershipPurpose.contactConsents[1];
        membershipEmailConsent.channel = 'Email';
        membershipEmailConsent.isChanged = true;
        membershipEmailConsent.privacyConsentStatusOldValue = 'OptIn';
        membershipEmailConsent.privacyConsentStatusNewValue = 'OptOut';
        membershipEmailConsent.legalBasis = 'Consent';
        ContactConsentController.ContactPointTypeConsentWrapper volunteeringPurpose = marketingPref.contactPointTypeConsents[1];
        ContactConsentController.ContactConsent volunteeringEmailConsent = volunteeringPurpose.contactConsents[0];
        volunteeringEmailConsent.channel = 'Email';
        volunteeringEmailConsent.isChanged = true;
        volunteeringEmailConsent.privacyConsentStatusOldValue = 'Unselected';
        volunteeringEmailConsent.privacyConsentStatusNewValue = 'OptOut';
        volunteeringEmailConsent.legalBasis = 'Consent';
        volunteeringEmailConsent.recordId = contactConsent1.Id;


        ContactConsentController.ContactPointTypeConsentByPreference productPref = conConsentInfo.preferences[1];
        ContactConsentController.ContactPointTypeConsentWrapper preventionPurpose = productPref.contactPointTypeConsents[0];
        ContactConsentController.ContactConsent preventionPostConsent = preventionPurpose.contactConsents[0];
        preventionPostConsent.channel = 'Post';
        preventionPostConsent.isChanged = true;
        preventionPostConsent.privacyConsentStatusOldValue = 'Unselected';
        preventionPostConsent.privacyConsentStatusNewValue = 'OptOut';
        preventionPostConsent.legalBasis = 'Consent';

        String summary = ContactConsentController.getContactConsentSummary(JSON.serializePretty(conConsentInfo), acc.Id);

       
        ContactConsentController.Summary resultSummary = (ContactConsentController.Summary) JSON.deserialize(summary, ContactConsentController.Summary.class);
        system.assertEquals(2, resultSummary.contactConsentSummarries.size());
        system.assertEquals(3, resultSummary.contactConsentSummarries[0].purposeSummarries.size());
        system.assertEquals(1, resultSummary.contactConsentSummarries[1].purposeSummarries.size());

        

        String result = ContactConsentController.saveConsentRecords(JSON.serializePretty(resultSummary.contactConsentSummarries), acc.Id, camp.Id,'Email', Datetime.now(), '');

        contactConsent1 = [SELECT PrivacyConsentStatus FROM ContactPointTypeConsent WHERE Id = :contactConsent1.Id];
        system.assertEquals('OptOut', contactConsent1.PrivacyConsentStatus);

        contactConsent2 = [SELECT PrivacyConsentStatus FROM ContactPointTypeConsent WHERE Id = :contactConsent2.Id];
        system.assertEquals('OptIn', contactConsent2.PrivacyConsentStatus);

        List<ContactPointTypeConsent> membershipPostConsents = new List<ContactPointTypeConsent>([SELECT Id, PrivacyConsentStatus FROM ContactPointTypeConsent WHERE PartyId = :acc.PersonIndividualId AND Channel__c = 'Post' AND DataUsePurposeId = :membership.Id]);
        system.assertEquals(1, membershipPostConsents.size());
        system.assertEquals('OptIn', membershipPostConsents[0].PrivacyConsentStatus);

        List<ContactPointTypeConsent> volunteeringEmailConsents = new List<ContactPointTypeConsent>([SELECT Id, PrivacyConsentStatus FROM ContactPointTypeConsent WHERE PartyId = :acc.PersonIndividualId AND Channel__c = 'Email' AND DataUsePurposeId = :volunteering.Id]);
        system.assertEquals(1, volunteeringEmailConsents.size());
        system.assertEquals('OptOut', volunteeringEmailConsents[0].PrivacyConsentStatus);

        List<ContactPointTypeConsent> preventionPostConsents = new List<ContactPointTypeConsent>([SELECT Id, PrivacyConsentStatus FROM ContactPointTypeConsent WHERE PartyId = :acc.PersonIndividualId AND Channel__c = 'Post' AND DataUsePurposeId = :prevention.Id]);
        system.assertEquals(1, preventionPostConsents.size());
        system.assertEquals('OptOut', preventionPostConsents[0].PrivacyConsentStatus);
    }
}