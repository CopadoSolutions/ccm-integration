/**
 * Implementation class for Microsoft VSTS. This class can be customized including extra logic, and cloned for supporting another provider.
 *
 * How to schedule the fetch process:
 * ScheduleUserStoryFetch Susf = new ScheduleUserStoryFetch (prpjectRecordId);
 * String str = Datetime.now().addSeconds(5).format('s m H d M ? yyyy');
 * String jobID = system.schedule('ScheduleUserStoryFetch - ' + DateTime.Now() + '.' + math.mod(DateTime.now().getTime(), 1000), str, Susf);
 * @author Ümit Can Uçkan
 * @version 1.0
 * @since CCM Integrations 1.0
 */

public without sharing class VSTSIntegration implements IIntegration{
    //will be filled with related project/user Story record
    public String projectExtId;
    public String workspaceId;
    public String namedCredential;

    //endpoint path to reach work items ids
    public final String authQueryPath = '/_apis/wit/wiql/';
    //endpoint api version
    public final String authApiVersion = '?api-version=4.1';
    //endpoint path to reach work items returned from query callout
    public final String workspacePath = '/_apis/wit/workitems?ids=';
    //endpoint path to use on patch operation
    public final String workspacePath2Patch = '_apis/wit/workitems/';

    //headers for callout
    public final String contentTypeHeader = 'Content-Type:application/json';
    public final String contentTypeHeader4Patch = 'Content-Type:application/json-patch+json';
    public final String connectionHeader = 'Connection:keep-alive';
    public final String overridePostMethod = 'X-HTTP-Method-Override:PATCH';

    //Json template to use on String.format function
    public final String JsonTemplate ='"op": "add","path": "/fields/{0}","value": "{1}"';

    //current copado__Project__c record id
    public Id pId;

    //user story Object's record types map to match the name from third party platforms
    static final Map<String,Id> recordTypeMap;
    static {
        recordTypeMap = new Map<String,id>();
        for(RecordType rt:[SELECT Id,Name,sObjectType FROM RecordType WHERE sObjectType='copado__user_story__c']){
            recordTypeMap.put(rt.Name,rt.Id);
        }
    }

    //list to return serialized Json values to batch
    public List<Map<String,String>> userStoryList {
        get {
            if(null == userStoryList){
                userStoryList = new List<Map<String,String>>();
            }
            return userStoryList;
        }
        set;
    }

    //VSTS work Items id set to use on the second callout
    public List<String> wIIds {
        get {
            if(null == wIIds){
                wIIds = new List<String>();
            }
            return wIIds;
        }
        set;
    }

    //Field mapping values between salesforce and third party platform fields under related project
    public Map<String,String> fieldMap {
        get {
            if(null == fieldMap){
                fieldMap = CopadoCCMutilities.returnFieldMap(pId,' and Exclude_from_tpu__c = false');
            }
            return fieldMap;
        }
        set;
    }

    //String comma seperated queries to us on sObject record query on updateRecord method
    public String queryFields {
        get {
            if(String.isBlank(queryFields)){
                queryFields = String.join(new List<String>(fieldMap.keyset()),',');
            }
            return queryFields;
        }
        set;
    }

    /**
     * Updates single record based on external Id on VSTS.
     * This method will be triggered by the SendUpdatedValues2TP Process Builder Flow on User Story change criteria (customizable in the flow).
     *
     * @param usItem
     */
    public void updateRecord(copado__User_Story__c usItem){
        pId = usItem.copado__Project__c;
        projectExtId = usItem.copado__Project__r.Project_External_Id__c;
        workspaceId = usItem.copado__Project__r.Workspace_Id__c;
        Id usId = usItem.Id;
        sObject cUserStory = database.query('SELECT '+queryFields+',enable_logs__c FROM copado__user_story__c WHERE id=:usId');
        String finalJson = '[{';
        for(String s:fieldMap.keyset()){
            if(null != cUserStory.get(s)){
                finalJson += String.format(JsonTemplate,new List<String>{fieldMap.get(s),String.escapeSingleQuotes(String.valueOf(cUserStory.get(s)))}) + '},{';
            }
        }
        System.debug('finalJson==> '+finalJson);
        //callout body to update VSTS record which is created from field mappings under related project and current field values
        finalJson = finalJson.substring(0,finalJson.length()-2) + ']';
        namedCredential = usItem.copado__Project__r.Copado_Integration_Setting__r.Named_Credential__c;
        //callout for field update
        String responseText = CopadoCCMutilities.MakeCallout(namedCredential,workspacePath2Patch,authApiVersion,(String)cUserStory.get('External_Id__c'),'',new List<String>{contentTypeHeader4Patch,connectionHeader,overridePostMethod},Method.POST,finalJson,cUserStory,null);
        CopadoCCMutilities.createLogRecords();
    }

    /**
     * Fetches records from Jira in JSON format
     *
     * @param selectedProject
     *
     * @return List<Map<String,String>>
     */
    public List<Map<String,String>> fetchRecords(copado__Project__c selectedProject){
        pid = selectedProject.Id;
        projectExtId = selectedProject.Project_External_Id__c;
        workspaceId = selectedProject.Workspace_Id__c;
        namedCredential = selectedProject.Copado_Integration_Setting__r.Named_Credential__c;
        //callout to find ids of the WorkItems exist on VSTS
        String responseText = CopadoCCMutilities.MakeCallout(namedCredential,projectExtId,workspaceId,authQueryPath,authApiVersion,new List<String>{contentTypeHeader},Method.GET,null,null,selectedProject);
        JSONParser parser = JSON.createParser(responseText);
        //wrapper class direct parse
        authWrapper authWrapperItem = (authWrapper)parser.readValueAs(authWrapper.class);
        for(workItemsWrapper wiw:authWrapperItem.workItems){
            wIIds.add(String.valueOf(wiw.Id));
        }
        //callout to have all fields for desired workItems
        String responseText2 = CopadoCCMutilities.MakeCallout(namedCredential,projectExtId,String.join(wIIds,','),workspacePath,'',new List<String>{contentTypeHeader,connectionHeader},Method.GET,null,null,selectedProject);
        JSONParser parser2 = JSON.createParser(responseText2);
        //wrapper class direct parse
        VSTSIntegration.queryWrapper queryWrapperItem = (VSTSIntegration.queryWrapper)parser2.readValueAs(VSTSIntegration.queryWrapper.class);

        for(valueWrapper vw:queryWrapperItem.value){
            userStoryList.add(vw.fields);
            for(String s:vw.fields.keyset()){
                if(s == 'System.WorkItemType' && recordTypeMap.containsKey(vw.fields.get(s))){
                    //fills up recordtypeId if the VSTS workItemtype name matches with any of the salesforce's recordtype name's on user story Object
                    vw.fields.put('recordTypeId',recordTypeMap.get(vw.fields.get(s)));
                }
                else if(s == 'System.AssignedTo' && vw.fields.get(s).contains('<')){
                    //fills up user look up fields, if email address in use on Third Party Platform matches any of the email addresses on current salesforce org.
                    String cuEmail = vw.fields.get(s).subStringAfter('<').subStringBefore('>');
                    if(CopadoCCMutilities.userMap.containsKey(cuEmail)){
                        vw.fields.put('developer',CopadoCCMutilities.userMap.get(cuEmail));
                    }
                }
                else vw.fields.put(s.toLowerCase(),vw.fields.get(s).toLowerCase());
            }
            //below four rows are in use for look up and external id purpose
            vw.fields.put('id',String.valueOf(vw.id));
            vw.fields.put('url',String.valueOf(vw.url));
            vw.fields.put('rev',String.valueOf(vw.rev));
            vw.fields.put('projectid',pid);
        }
        CopadoCCMutilities.createLogRecords();
        //returns list to executeUserStoryUpsert batch class
        return this.userStoryList;
    }

    /**
     *  Nested wrapper classes to use on direct Json casting on authentication callout step
     */
    public class authWrapper{
        public String queryType;
        public String queryResultType;
        public String asOf;
        public List<columnsWrapper> columns;
        public List<sortColumnsWrapper> sortColumns;
        public List<workItemsWrapper> workItems;
    }
    public class columnsWrapper{
        public String referenceName;
        public String name;
        public String url;
    }
    public class sortColumnsWrapper{
        public sortColumnsfieldWrapper field;
        public Boolean descending;
    }
    public class workItemsWrapper{
        public Integer id;
        public String url;
    }
    public class sortColumnsfieldWrapper{
        public String referenceName;
        public String name;
        public String url;
    }

    public class queryWrapper{
        public Integer count;
        public List<valueWrapper> value;
    }
    public class valueWrapper{
        public Integer id;
        public Integer rev;
        public Map<String,String> fields;
        public String url;
    }
}