/**
 * Invocable class to send updates from Copado to External Provider.
 *
 * @author Ümit Can Uçkan
 * @version 1.0
 * @since CCM Integrations 1.0
 */
public class UserStoryHandler{
    
    @InvocableMethod(Label='Call Factory for Third Party Update' Description='Calls Integration Factory to make callout')
    public static void callFactory4ThirdPartyUpdate(List<copado__User_Story__c> usRecords) {
        Set<Id> usIds = new Set<Id>();
        for(copado__User_Story__c us:usRecords){
            usIds.add(us.Id);
        }
        if(!System.isFuture() && !System.isBatch()) {
            callFactory4ThirdPartyUpdate(usIds);
        }
    } 
    @future(callout=true)
    public static void callFactory4ThirdPartyUpdate(Set<Id> usIds){
        List<copado__User_Story__c> userStoryList = [SELECT Id,External_Id__c,copado__Project__c,copado__Project__r.Project_External_Id__c,copado__Project__r.Workspace_Id__c,
                                                            copado__Project__r.Copado_Integration_Setting__r.External_System__c,copado__Project__r.Copado_Integration_Setting__r.Named_Credential__c
                                                     FROM copado__User_Story__c
                                                     WHERE id IN :usIds AND copado__Project__c != null AND copado__Project__r.Copado_Integration_Setting__c != null AND External_Id__c != null];
        for(copado__User_Story__c usItem:userStoryList){
            IntegrationFactory.returnInstance(usItem.copado__Project__r.Copado_Integration_Setting__r.External_System__c).updateRecord(usItem);
        }
    }
}