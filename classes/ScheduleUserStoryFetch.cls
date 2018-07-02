/**
 * Schedulable class to retrieve external User Stories on a scheduled basis.
 *
 * @author Ümit Can Uçkan
 * @version 1.0
 * @since CCM Integrations 1.0
 */
global class ScheduleUserStoryFetch implements Schedulable
{
    copado__Project__c cpRecord;
    public ScheduleUserStoryFetch(Id pId){
        cpRecord = [SELECT Id,Name, Copado_Integration_Setting__r.External_System__c, Copado_Integration_Setting__r.Named_Credential__c,JQL_Extended_Filter__c,Enable_Logs__c,
                           Project_External_Id__c, Workspace_Id__c FROM copado__Project__c WHERE Id=:pId];
    }

    global void execute(SchedulableContext sc)
    {
        Database.executeBatch(new ExecuteUserStoryUpsert(this.cpRecord),200);
    }
}