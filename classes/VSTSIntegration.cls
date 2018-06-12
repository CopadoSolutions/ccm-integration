/**
 * Created by umitcanuckan on 05/06/2018.
 */

/*
* How to schedule the fetch process
*
* ScheduleUserStoryFetch Susf = new ScheduleUserStoryFetch (prpjectRecordId);
* String str = Datetime.now().addSeconds(5).format('s m H d M ? yyyy');
* String jobID = system.schedule('ScheduleUserStoryFetch - ' + DateTime.Now() + '.' + math.mod(DateTime.now().getTime(), 1000), str, Susf);
*
* */

public without sharing class VSTSIntegration implements IIntegration{
    //will be filled with related project/user Story record
    public string projectExtId;
    public string workspaceId;
    public string namedCredential;

    //endpoint path to reach work items ids
    public final string authQueryPath = '/_apis/wit/wiql/';
    //endpoint api version
    public final string authApiVersion = '?api-version=4.1';
    //endpoint path to reach work items returned from query callout
    public final string workspacePath = '/_apis/wit/workitems?ids=';
    //endpoint path to use on patch operation
    public final string workspacePath2Patch = '_apis/wit/workitems/';

    //headers for callout
    public final string contentTypeHeader = 'Content-Type:application/json';
    public final string contentTypeHeader4Patch = 'Content-Type:application/json-patch+json';
    public final string connectionHeader = 'Connection:keep-alive';
    public final string overridePostMethod = 'X-HTTP-Method-Override:PATCH';

    //Json template to use on string.format function
    public final string JsonTemplate ='"op": "add","path": "/fields/{0}","value": "{1}"';

    //current copado__project__c record id
    public id pId;

    //user story object's record types map to match the name from third party platforms
    static final Map<string,id> recordTypeMap;
    static{
        recordTypeMap = new Map<string,id>();
        for(recordType rt:[select id,name,sobjecttype from recordType where sobjecttype='copado__user_story__c']){
            recordTypeMap.put(rt.name,rt.id);
        }
    }

    //list to return serialized Json values to batch
    public List<Map<string,string>> userStoryList {get{
        if(null == userStoryList){
            userStoryList = new List<Map<string,string>>();
        }
        return userStoryList;
    }set;}

    //VSTS work Items id set to use on the second callout
    public List<string> wIIds {get{
        if(null == wIIds){
            wIIds = new List<string>();
        }
        return wIIds;
    }set;}

    //Field mapping values between salesforce and third party platform fields under related project
    public Map<string,string> fieldMap {get{
        if(null == fieldMap){
            fieldMap = Utilities.returnFieldMap(pId,' and Exclude_from_tpu__c = false');
        }
        return fieldMap;
    }set;}

    //string comma seperated queries to us on sObject record query on updateRecord method
    public string queryFields {get{
        if(string.isBlank(queryFields)){
            queryFields = string.join(new List<string>(fieldMap.keyset()),',');
        }
        return queryFields;
    }set;}

    //updates single record based on the external id on VSTS
    //this method will be triggered by the SendUpdatedValues2TP process on user story status change.
    //You can clone the proces and change the firing conditions anytime
    public void updateRecord(copado__user_story__c usItem){
        pId = usItem.copado__Project__c;
        projectExtId = usItem.copado__Project__r.Project_External_Id__c;
        workspaceId = usItem.copado__Project__r.Workspace_Id__c;
        id usId = usItem.id;
        sObject cUserStory = database.query('select '+queryFields+',enable_logs__c from copado__user_story__c where id=:usId');
        string finalJson = '[{';
        for(string s:fieldMap.keyset()){
            if(null != cUserStory.get(s)){
                finalJson += string.format(JsonTemplate,new List<string>{fieldMap.get(s),string.escapeSingleQuotes(string.valueOf(cUserStory.get(s)))}) + '},{';
            }
        }
        //callout body to update VSTS record which is created from field mappings under related project and current field values
        finalJson = finalJson.substring(0,finalJson.length()-2) + ']';
        namedCredential = usItem.copado__Project__r.Copado_Integration_Setting__r.Named_Credential__c;
        //callout for field update
        string responseText = Utilities.MakeCallout(namedCredential,workspacePath2Patch,authApiVersion,(string)cUserStory.get('External_Id__c'),'',new List<string>{contentTypeHeader4Patch,connectionHeader,overridePostMethod},Method.POST,finalJson,cUserStory,null);
        utilities.createLogRecords();
    }

    public List<Map<string,string>> fetchRecords(copado__Project__c selectedProject){
        pid = selectedProject.id;
        projectExtId = selectedProject.Project_External_Id__c;
        workspaceId = selectedProject.Workspace_Id__c;
        namedCredential = selectedProject.Copado_Integration_Setting__r.Named_Credential__c;
        //callout to find ids of the WorkItems exist on VSTS
        string responseText = Utilities.MakeCallout(namedCredential,projectExtId,workspaceId,authQueryPath,authApiVersion,new List<string>{contentTypeHeader},Method.GET,null,null,selectedProject);
        JSONParser parser = JSON.createParser(responseText);
        //wrapper class direct parse
        authWrapper authWrapperItem = (authWrapper)parser.readValueAs(authWrapper.class);
        for(workItemsWrapper wiw:authWrapperItem.workItems){
            wIIds.add(string.valueOf(wiw.id));
        }
        //callout to have all fields for desired workItems
        string responseText2 = Utilities.MakeCallout(namedCredential,projectExtId,string.join(wIIds,','),workspacePath,'',new List<string>{contentTypeHeader,connectionHeader},Method.GET,null,null,selectedProject);
        JSONParser parser2 = JSON.createParser(responseText2);
        //wrapper class direct parse
        VSTSIntegration.queryWrapper queryWrapperItem = (VSTSIntegration.queryWrapper)parser2.readValueAs(VSTSIntegration.queryWrapper.class);

        for(valueWrapper vw:queryWrapperItem.value){
            userStoryList.add(vw.fields);
            for(string s:vw.fields.keyset()){
                if(s == 'System.WorkItemType' && recordTypeMap.containsKey(vw.fields.get(s))){
                    //fills up recordtypeId if the VSTS workItemtype name matches with any of the salesforce's recordtype name's on user story object
                    vw.fields.put('recordTypeId',recordTypeMap.get(vw.fields.get(s)));
                }
                else if(s == 'System.AssignedTo' && vw.fields.get(s).contains('<')){
                    //fills up user look up fields, if email address in use on Third Party Platform matches any of the email addresses on current salesforce org.
                    string cuEmail = vw.fields.get(s).subStringAfter('<').subsTringBefore('>');
                    if(Utilities.userMap.containsKey(cuEmail)){
                        vw.fields.put('developer',Utilities.userMap.get(cuEmail));
                    }
                }
                else vw.fields.put(s.toLowerCase(),vw.fields.get(s).toLowerCase());
            }//TODO: spesify the fields that set by you in the documentation!!!
            //below four rows are in use for look up and external id purpose
            vw.fields.put('id',string.valueOf(vw.id));
            vw.fields.put('url',string.valueOf(vw.url));
            vw.fields.put('rev',string.valueOf(vw.rev));
            vw.fields.put('projectid',pid);
        }
        utilities.createLogRecords();
        //returns list to executeUserStoryUpsert batch class
        return this.userStoryList;
    }

    //nested wrapper classes to use on direct Json casting on authentication callout step
    public class authWrapper{
        public string queryType;
        public string queryResultType;
        public string asOf;
        public List<columnsWrapper> columns;
        public List<sortColumnsWrapper> sortColumns;
        public List<workItemsWrapper> workItems;
    }
    public class columnsWrapper{
        public string referenceName;
        public string name;
        public string url;
    }
    public class sortColumnsWrapper{
        public sortColumnsfieldWrapper field;
        public boolean descending;
    }
    public class workItemsWrapper{
        public integer id;
        public string url;
    }
    public class sortColumnsfieldWrapper{
        public string referenceName;
        public string name;
        public string url;
    }

    public class queryWrapper{
        public integer count;
        public List<valueWrapper> value;
    }
    public class valueWrapper{
        public integer id;
        public integer rev;
        public Map<string,string> fields;
        public string url;
    }
}