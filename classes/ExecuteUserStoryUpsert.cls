/**
 * Upserts an External User Story into Copado's User Story.
 *
 * @author Ümit Can Uçkan
 * @version 1.0
 * @since CCM Integrations 1.0
 */

global class ExecuteUserStoryUpsert implements Database.Batchable<Object>,Database.AllowsCallouts{

    global copado__Project__c gProject;
    List<copado__User_Story__c> userStories2Upsert;
    //Field mapping values between salesforce and third party platform fields under related project
    global Map<String,String> fieldMap {get{
        if(null == fieldMap){
            fieldMap = CopadoCCMutilities.returnFieldMap(gProject.Id,' and Exclude_from_su__c = false');
        }
        return fieldMap;
    }set;}
    //constructor to have the project via schedule class
    global ExecuteUserStoryUpsert(copado__Project__c proParam){
        gProject = proParam;
    }
    //Finds related instance based on external system to use via factory pattern, fetches and parses the JSON and return to execute method
    global Iterable<Object> start(Database.BatchableContext BC){
        return new CallIterable(IntegrationFactory.returnInstance(gProject.Copado_Integration_Setting__r.External_System__c).fetchRecords(gProject));
    }

    global void execute(Database.BatchableContext BC, List<Object> scope){
        userStories2Upsert = new List<copado__User_Story__c>();
        //loops among user story Items Map
        for(Object usItem:scope){
            Map<String,String> tempMap = (Map<String,String>)usItem;
            sObject sobj = new copado__User_Story__c();
            //loops among field Mapping items under related project
            for(String s:fieldMap.keyset()){
                s = s.toLowerCase();
                //puts the value on sf Object if the current user story item value Map stores current field Map keyset
                if(tempMap.containsKey(fieldMap.get(s))){
                    sobj.put(s,CopadoCCMutilities.returnCastedValue(tempMap.get(fieldMap.get(s)),s));
                }
            }
            userStories2Upsert.add((copado__User_Story__c)sobj);
        }
        try {
            //performs upsert based on third party id
            upsert userStories2Upsert External_Id__c;
        }catch(DmlException ex){
            System.debug('here is the exception==> '+ex.getMessage());
        }
    }

    global void finish(Database.BatchableContext BC){
    }
}