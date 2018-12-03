/**
 * Created by copado on 05/06/2018.
*
* How to schedule the fetch process
*
* ScheduleUserStoryFetch Susf = new ScheduleUserStoryFetch (prpjectRecordId);
* String str = Datetime.now().addSeconds(5).format('s m H d M ? yyyy');
* String jobID = system.schedule('ScheduleUserStoryFetch - ' + DateTime.Now() + '.' + math.mod(DateTime.now().getTime(), 1000), str, Susf);
*
* */

public without sharing class VSTSIntegration implements IIntegration{
    //will be filled with related project/user Story record
    public String projectExtId;
    public String workspaceId;
    public String namedCredential;
    public final Integer vstsPaginationSize { get{
        if(null == vstsPaginationSize){
            vstsPaginationSize = 100;
        }
        return vstsPaginationSize;
    }set;}

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

    //Json template to use on string.format function
    public final String JsonTemplate ='"op": "add","path": "/fields/{0}","value": "{1}"';

    //current copado__project__c record id
    public Id pId;

    //user story object's record types map to match the name from third party platforms
    static final Map<String,id> recordTypeMap;
    static{
        recordTypeMap = new Map<string,id>();
        for(RecordType rt:[SELECT id,name,sobjecttype FROM RecordType WHERE sobjecttype='copado__user_story__c']){
            recordTypeMap.put(rt.name,rt.id);
        }
    }

    //list to return serialized Json values to batch
    public List<Map<String,String>> userStoryList {get{
        if(null == userStoryList){
            userStoryList = new List<Map<String,String>>();
        }
        return userStoryList;
    }set;}

    //VSTS work Items id set to use on the second callout
    public List<List<String>> wIIds {get{
        if(null == wIIds){
            wIIds = new List<List<String>>();
        }
        return wIIds;
    }set;}

    //Field mapping values between salesforce and third party platform fields under related project
    public Map<String,String> fieldMap {get{
        if(null == fieldMap){
            fieldMap = CopadoCCMutilities.returnFieldMap(pId,' and Exclude_from_tpu__c = false');
        }
        return fieldMap;
    }set;}

    //string comma seperated queries to us on sObject record query on updateRecord method
    public String queryFields {get{
        if(String.isBlank(queryFields)){
            queryFields = String.join(new List<String>(fieldMap.keyset()),',');
        }
        return queryFields;
    }set;}

    //updates single record based on the external id on VSTS
    //this method will be triggered by the SendUpdatedValues2TP process on user story status change.
    //You can clone the proces and change the firing conditions anytime
    public void updateRecord(copado__User_story__c usItem){
        pId = usItem.copado__Project__c;
        projectExtId = usItem.copado__Project__r.Project_External_Id__c;
        workspaceId = usItem.copado__Project__r.Workspace_Id__c;
        Id usId = usItem.id;
        Sobject cUserStory = Database.query('select '+queryFields+',enable_logs__c from copado__user_story__c where id=:usId');
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

    public List<Map<String,String>> fetchRecords(copado__Project__c selectedProject){
        pid = selectedProject.id;
        projectExtId = selectedProject.Project_External_Id__c;
        workspaceId = selectedProject.Workspace_Id__c;
        namedCredential = selectedProject.Copado_Integration_Setting__r.Named_Credential__c;
        //callout to find ids of the WorkItems exist on VSTS
        String responseText = CopadoCCMutilities.MakeCallout(namedCredential,projectExtId,workspaceId,authQueryPath,authApiVersion,new List<String>{contentTypeHeader},Method.GET,null,null,selectedProject);
        JSONParser parser = JSON.createParser(responseText);
        //wrapper class direct parse
        authWrapper authWrapperItem = (authWrapper)parser.readValueAs(authWrapper.class);
        Integer counter4Ids=0,currentIndex=0;
        for(workItemsWrapper wiw:authWrapperItem.workItems){
            if(counter4Ids == 0){
                wIIds.add(new List<String>());
            }
            wIIds[currentIndex].add(String.valueOf(wiw.id));
            counter4Ids++;
            if(counter4Ids == vstsPaginationSize){
                counter4Ids = 0;
                currentIndex++;
            }
        }
        for(Integer idCounter=0;idCounter < wIIds.size();idCounter++) {
            //callout to have all fields for desired workItems
            String responseText2 = CopadoCCMutilities.MakeCallout(namedCredential, projectExtId, string.join(wIIds[idCounter], ','), workspacePath, '', new List<string>{
                    contentTypeHeader, connectionHeader
            }, Method.GET, null, null, selectedProject);
            responseText2 = responseText2.replace('\\','');
            responseText2 = responseText2.replace('="','=\\"');
            responseText2 = responseText2.replace('">','\\">');
            Map<String, Object> results = (Map<String, Object>) JSON.deserializeUntyped(responseText2);
            List<Object> values = (List<Object>) results.get('value');
            Map<String, String> keyValuepairTempMap;

            for (Object value : values) {
                Map<String, Object> currentValue = (Map<String, Object>) value;
                keyValuepairTempMap = new Map<String, String>();
                if (null != currentValue.get('fields')) {
                    Map<String, Object> fields = (Map<String, Object>) currentValue.get('fields');
                    for (String sItem : fields.keyset()) {
                        if (sItem == 'System.WorkItemType' && recordTypeMap.containsKey((String)fields.get(sItem))) {
                            //fills up recordtypeId if the VSTS workItemtype name matches with any of the salesforce's recordtype name's on user story object
                            keyValuepairTempMap.put('recordtypeid', recordTypeMap.get((String)fields.get(sItem)));
                        } else if (sItem == 'System.AssignedTo' && String.valueOf(fields.get(sItem)).contains('<')) {
                            //fills up user look up fields, if email address in use on Third Party Platform matches any of the email addresses on current salesforce org.
                            String cuEmail = String.valueOf(fields.get(sItem)).subStringAfter('<').subsTringBefore('>');
                            if (CopadoCCMutilities.userMap.containsKey(cuEmail)) {
                                keyValuepairTempMap.put('developer', CopadoCCMutilities.userMap.get(cuEmail));
                            }
                        }else if (fields.get(sItem) instanceof String || fields.get(sItem) instanceof Integer || fields.get(sItem) instanceof Decimal || fields.get(sItem) instanceof Double || fields.get(sItem) == null) {
                            //Prepares values from String
                            keyValuepairTempMap.put(sItem.toLowerCase(), String.valueOf(fields.get(sItem)));
                        }else if (fields.get(sItem) instanceof Map<String, Object>) {
                            //Prepares values from Json Object
                            Map<String, Object> tempObject = (Map<String, Object>) fields.get(sItem);
                            if (null != tempObject.get('uniqueName')) {
                                String cuEmail = String.valueOf(tempObject.get('uniqueName')).toLowerCase();
                                if (CopadoCCMutilities.userMap.containsKey(cuEmail)) {
                                    keyValuepairTempMap.put(sItem.toLowerCase(), CopadoCCMutilities.userMap.get(cuEmail));
                                }
                            }else if (null != tempObject.get('displayName')) {
                                keyValuepairTempMap.put(sItem.toLowerCase(), (String) tempObject.get('displayName'));
                            }
                        }else keyValuepairTempMap.put(sItem.toLowerCase(), String.valueOf(fields.get(sItem)));
                    }
                    //below four rows are in use for look up and external id purpose
                    keyValuepairTempMap.put('id', String.valueOf(currentValue.get('id')));
                    keyValuepairTempMap.put('url', String.valueOf(currentValue.get('url')));
                    keyValuepairTempMap.put('rev', String.valueOf(currentValue.get('rev')));
                    keyValuepairTempMap.put('projectid', pid);
                    userStoryList.add(keyValuepairTempMap);
                }
            }
        }
        CopadoCCMutilities.createLogRecords();
        //returns list to executeUserStoryUpsert batch class
        return this.userStoryList;
    }

    //nested wrapper classes to use on direct Json casting on authentication callout step
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
}
