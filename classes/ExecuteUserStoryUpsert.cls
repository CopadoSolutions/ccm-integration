/**
 * Created by umitcanuckan on 07/06/2018.
 */


 global class ExecuteUserStoryUpsert implements Database.batchable<object>,Database.AllowsCallouts{

     global copado__Project__c gProject;
     List<copado__User_Story__c> userStories2Upsert;
     //Field mapping values between salesforce and third party platform fields under related project
     global Map<string,string> fieldMap {get{
         if(null == fieldMap){
             fieldMap = Utilities.returnFieldMap(gProject.id,' and Exclude_from_su__c = false');
         }
         return fieldMap;
     }set;}
     //constructor to have the project via schedule class
     global ExecuteUserStoryUpsert(copado__Project__c proParam){
         gProject = proParam;
     }
     //Finds related instance based on external system to use via factory pattern, fetches and parses the JSON and return to execute method
     global Iterable<object> start(Database.BatchableContext BC){
         return new CallIterable(IntegrationFactory.returnInstance(gProject.Copado_Integration_Setting__r.External_System__c).fetchRecords(gProject));
     }

     global void execute(Database.BatchableContext BC, List<object> scope){
         userStories2Upsert = new List<copado__User_Story__c>();
         //loops among user story Items Map
         for(object usItem:scope){
             system.debug('usItem==> '+usItem);
             Map<string,string> tempMap = (Map<string,string>)usItem;
             system.debug('tempMap==> '+tempMap);
             sObject sobj = new copado__User_Story__c();
             //loops among field Mapping items under related project
             for(string s:fieldMap.keyset()){
                 s = s.toLowerCase();
                 system.debug('s==> '+s);
                 //puts the value on sf object if the current user story item value Map stores current field Map keyset
                 if(tempMap.containsKey(fieldMap.get(s))){
                     system.debug('s==> '+s);
                     system.debug('fieldMap.get(s)==> '+fieldMap.get(s));
                     system.debug('tempMap.get(fieldMap.get(s))==> '+tempMap.get(fieldMap.get(s)));
                     sobj.put(s,Utilities.returnCastedValue(tempMap.get(fieldMap.get(s)),s));
                 }
             }
             userStories2Upsert.add((copado__User_Story__c)sobj);
         }
         system.debug('userStories2Upsert==> '+userStories2Upsert);
         try {
             //performs upsert based on third party id
             upsert userStories2Upsert external_id__c;
         }catch(dmlException ex){
             system.debug('here is the exception==> '+ex.getMessage());
         }
     }

     global void finish(Database.BatchableContext BC){
     }
 }