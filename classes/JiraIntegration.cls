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

public with sharing class JiraIntegration implements IIntegration{
    //will be filled with related project/user Story record
    public string projectExtId;
    public string namedCredential;

    //endpoint path to fetch records from JIRA
    public final string authQueryPath = 'search?jql=project=';

    //headers for callout
    public final string contentTypeHeader = 'Content-Type:application/json';
    public final string connectionHeader = 'Connection:keep-alive';

    //Json template to use on string.format function for object types
    public final string JsonTemplateInnerObject = '"{0}" :lcurly"name" : "{1}"rcurly';
    //Json template to use on string.format function for string types
    public final string JsonTemplateInnerString = '"{0}" :"{1}"';
    public final string JsonTemplateOuter = '{"fields" : {';

    //template to be able to change the status via transition
    //in use on updateStatus method
    public string transitionTemplate = 'lcurly"transition":lcurly"id":"{0}"rcurlyrcurly';

    //endpoint path to reach to specified issue
    public string updateParameterString = 'issue/{0}';
    //endpoint path to fetch available statuses on related issue
    public string updateParameter4TransitionString = 'issue/{0}/transitions?Expand=transitions.fields';

    //current copado__project__c record id
    public id pId;

    //List of Map collector to be able to return records from json response to batch class
    public List<Map<string,string>> userStoryList {get{
        if(null == userStoryList){
            userStoryList = new List<Map<string,string>>();
        }
        return userStoryList;
    }set;}

    //salesforce field api to third party field Mapping to use on third party record update operation
    public Map<string,string> fieldMap {get{
        if(null == fieldMap){
            fieldMap = Utilities.returnFieldMap(pId,' and Exclude_from_tpu__c = false');
        }
        return fieldMap;
    }set;}

    //salesforce field api to third party field type Mapping to use on third party record update operation
    //exps: copado__status__c => object
    public Map<string,string> typeMap {get{
        if(null == typeMap){
            typeMap = Utilities.returnTargetTypeMap(pId,' and Exclude_from_tpu__c = false');
        }
        return typeMap;
    }set;}

    //string comma seperated queries to us on sObject record query on updateRecord method
    public string queryFields {get{
        if(string.isBlank(queryFields)){
            queryFields = string.join(new List<string>(fieldMap.keyset()),',');
        }
        return queryFields;
    }set;}

    //updates single record based on the external id on JIRA
    //this method will be triggered by the SendUpdatedValues2TP process on user story status change.
    //You can clone the proces and change the firing conditions anytime
    public void updateRecord(copado__user_story__c usItem){
        pId = usItem.copado__Project__c;
        projectExtId = usItem.copado__Project__r.Project_External_Id__c;
        namedCredential = usItem.copado__Project__r.Copado_Integration_Setting__r.Named_Credential__c;
        id usId = usItem.id;
        sObject cUserStory = database.query('select '+queryFields+',external_id__c,enable_logs__c from copado__user_story__c where id=:usId');
        string finalJson = JsonTemplateOuter;
        for(string s:fieldMap.keyset()){
            if(null != cUserStory.get(s) && fieldMap.get(s) != 'status'){
                finalJson += string.format((typeMap.get(s) == 'object' ? JsonTemplateInnerObject : JsonTemplateInnerString), new List<string>{fieldMap.get(s), string.escapeSingleQuotes(string.valueOf(cUserStory.get(s)))}) + ',';
            }
        }
        //callout body to update JIRA record which is created from field mappings under related project and current field values
        finalJson = Utilities.replaceFromCurly(finalJson.substring(0,finalJson.length()-1) + '}}');

        string responseText = Utilities.MakeCallout(namedCredential,'','',string.format(updateParameter4TransitionString,new List<string>{(string)cUserStory.get('External_Id__c')}),'',new List<string>{contentTypeHeader},Method.GET,null,cUserStory,null);
        //JIRA status update on a different method, since status is a state, not a field on JIRA
        updateStatus(responseText,cUserStory);

        //callout for field update
        string responseTextFields = Utilities.MakeCallout(namedCredential,'','',string.format(updateParameterString,new List<string>{(string)cUserStory.get('External_Id__c')}),'',new List<string>{contentTypeHeader},Method.PUT,finalJson,cUserStory,null);
        utilities.createLogRecords();
    }
    //fetched records from JIRA as Json
    public List<Map<string,string>> fetchRecords(copado__Project__c selectedProject){
        pid = selectedProject.id;
        projectExtId = selectedProject.Project_External_Id__c;
        namedCredential = selectedProject.Copado_Integration_Setting__r.Named_Credential__c;
        integer startIndex = 0;
        boolean shouldContinue = true;
        integer total;
        //gets issues via jqr
        while(shouldContinue) {
            string responseText = Utilities.MakeCallout(namedCredential, '', projectExtId, authQueryPath, '&startAt=' + startIndex, new List<string>{
                    contentTypeHeader
            }, Method.GET, null, null, selectedProject);
            Map<String, Object> results = (Map<String, Object>) JSON.deserializeUntyped(responseText);
            total = Integer.valueOf(results.get('total'));
            startIndex = Integer.valueOf(results.get('startAt'));
            System.debug('Total number of issues: ' + total);
            List<Object> issues = (List<Object>) results.get('issues');
            Map<string, string> keyValuepairTempMap;
            for (Object issue : issues) {
                keyValuepairTempMap = new Map<string, string>();
                Map<string, Object> currentIssue = (Map<string, object>) issue;
                //below three rows are in use for look up and external id purpose
                keyValuepairTempMap.put('key', (string) currentIssue.get('key'));
                keyValuepairTempMap.put('id', (string) currentIssue.get('id'));
                keyValuepairTempMap.put('projectid', pid);
                if (null != currentIssue.get('fields')) {
                    Map<string, object> fields = (Map<string, object>) currentIssue.get('fields');
                    for (string cf : fields.keySet()) {
                        //prepares values from string
                        if (fields.get(cf) instanceof string || fields.get(cf) == null) {
                            keyValuepairTempMap.put(cf, (string) fields.get(cf));
                        }
                        //prepares values from Json object
                        else if (fields.get(cf) instanceof Map<string, object>) {
                            Map<string, object> tempObject = (Map<string, object>) fields.get(cf);
                            if (null != tempObject.get('emailAddress')) {
                                //fills up user look up fields, if email address in use on Third Party Platform matches any of the email addresses on current salesforce org.
                                string cuEmail = (string) tempObject.get('emailAddress');
                                if (cf == 'assignee' && Utilities.userMap.containsKey(cuEmail)) {
                                    keyValuepairTempMap.put('developer', utilities.userMap.get(cuEmail));
                                } else keyValuepairTempMap.put(cf, (string) tempObject.get('emailAddress'));
                            } else if (null != tempObject.get('name')) {
                                keyValuepairTempMap.put(cf, (string) tempObject.get('name'));
                            }
                        }
                    }
                    userStoryList.add(keyValuepairTempMap);
                }
            }
            if(total - startIndex < 50){
                shouldContinue = false;
            }else startIndex = startIndex + 50;
        }
        utilities.createLogRecords();
        //returns list to executeUserStoryUpsert batch class
        return this.userStoryList;
    }
    //updates JIRA status
    public void updateStatus(string responseText,sObject cUserStory){
        string statusfinalJson = '';
        JSONParser parser = JSON.createParser(responseText);
        //wrapper class direct parse
        transitionWrapper transitionWrapperItem = (transitionWrapper)parser.readValueAs(transitionWrapper.class);
        string currentStatusValue = (string)cUserStory.get('copado__status__c');
        boolean calloutFlag = false;
        for(transitions tw:transitionWrapperItem.transitions){
            //checks if the current status is available on JIRA workflow, if not, does not do the callout
            if(tw.name.toLowerCase() == currentStatusValue.toLowerCase()){
                statusfinalJson = Utilities.replaceFromCurly(string.format(transitionTemplate,new List<string>{tw.id}));
                calloutFlag = true;
                break;
            }
        }
        if(calloutFlag) Utilities.MakeCallout(namedCredential,'','',string.format(updateParameter4TransitionString,new List<string>{(string)cUserStory.get('External_Id__c')}),'',new List<string>{contentTypeHeader},Method.POST,statusfinalJson,cUserStory,null);
    }

    //Wrapper classes for direct casting of transition Callout response
    public class transitionWrapper{
        public List<transitions> transitions;
    }
    public class transitions{
        public string id;
        public string name;
    }
}