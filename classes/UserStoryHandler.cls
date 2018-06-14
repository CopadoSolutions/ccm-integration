public class UserStoryHandler{
    
    @InvocableMethod(label='Call Factory 4 Third Party Update' description='Calls Integration Factory to make callout')
    public static void callFactory4ThirdPartyUpdate(List<copado__user_story__c> usRecords) {
        set<id> usIds = new set<id>();
        for(copado__user_story__c us:usRecords){
            usIds.add(us.id);
        }
        if(!System.isFuture() && !System.isBatch()) {
            callFactory4ThirdPartyUpdate(usIds);
        }
    } 
    @future(callout=true)
    public static void callFactory4ThirdPartyUpdate(set<id> usIds){
        List<copado__user_story__c> userStoryList = [select id,external_id__c,copado__project__c,copado__project__r.Project_External_Id__c,copado__project__r.workspace_id__c,copado__project__r.Copado_Integration_Setting__r.External_System__c,copado__Project__r.Copado_Integration_Setting__r.Named_Credential__c from copado__user_story__c where id in:usIds and copado__project__c != null and copado__Project__r.Copado_Integration_Setting__c != null and external_id__c != null];
        for(copado__user_story__c usItem:userStoryList){
            IntegrationFactory.returnInstance(usItem.copado__project__r.Copado_Integration_Setting__r.External_System__c).updateRecord(usItem);
        }
    }
}