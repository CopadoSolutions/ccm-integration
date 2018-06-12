/**
 * Created by umitcanuckan on 07/06/2018.
 */


global class ScheduleUserStoryFetch Implements Schedulable
{
    copado__project__c cpRecord;
    public ScheduleUserStoryFetch(id pId){
        cpRecord = [select id,name, Copado_Integration_Setting__r.External_System__c, Copado_Integration_Setting__r.Named_Credential__c,enable_logs__c, Project_External_Id__c, workspace_id__c from copado__project__c where id=:pId];
    }

    global void execute(SchedulableContext sc)
    {
        Database.executeBatch(new ExecuteUserStoryUpsert(this.cpRecord),200);
    }
}