/**
 * Implementation class for Jira. This class can be customized including extra logic, and cloned for supporting another provider.
 *
 * How to schedule the fetch process:
 * ScheduleUserStoryFetch Susf = new ScheduleUserStoryFetch (prpjectRecordId);
 * String str = Datetime.now().addSeconds(5).format('s m H d M ? yyyy');
 * String jobID = system.schedule('ScheduleUserStoryFetch - ' + DateTime.Now() + '.' + math.mod(DateTime.now().getTime(), 1000), str, Susf);
 * @author Ümit Can Uçkan
 * @version 1.0
 * @since CCM Integrations 1.0
 */

public with sharing class JiraIntegration implements IIntegration {
    //will be filled with related project/user Story record
    public String projectExtId;
    public String namedCredential;
    public String jqlExtFilter {get{
        if(String.isBlank(jqlExtFilter)){
            jqlExtFilter = '';
        }
        return jqlExtFilter;
    } private set;}

    //endpoint path to fetch records from Jira
    public final String authQueryPath = 'search?jql=project=';

    //headers for callout
    public final String contentTypeHeader = 'Content-Type:application/json';
    public final String connectionHeader = 'Connection:keep-alive';

    //Json template to use on String.format function for Object types
    public final String JsonTemplateInnerObject = '"{0}" :lcurly"name" : "{1}"rcurly';
    //Json template to use on String.format function for String types
    public final String JsonTemplateInnerString = '"{0}" :"{1}"';
    //Json template to use on String.format function for Integer types
    public final String JsonTemplateInnerInteger = '"{0}" :{1}';
    public final String JsonTemplateOuter = '{"fields" : {';

    //template to be able to change the status via transition
    //in use on updateStatus method
    public String transitionTemplate = 'lcurly"transition":lcurly"id":"{0}"rcurlyrcurly';

    //endpoint path to reach to specified issue
    public String updateParameterString = 'issue/{0}';
    //endpoint path to fetch available statuses on related issue
    public String updateParameter4TransitionString = 'issue/{0}/transitions?Expand=transitions.fields';

    //current copado__project__c record id
    public Id pId;

    //List of Map collector to be able to return records from json response to batch class
    public List<Map<String,String>> userStoryList {
        get {
            if(null == userStoryList){
                userStoryList = new List<Map<String,String>>();
            }
            return userStoryList;
        }
        set;
    }

    //salesforce field api to third party field Mapping to use on third party record update operation
    public Map<String,String> fieldMap {
        get {
            if(null == fieldMap){
                fieldMap = CopadoCCMutilities.returnFieldMap(pId,' and Exclude_from_tpu__c = false');
            }
            return fieldMap;
        }
        set;
    }

    //salesforce field api to third party field type Mapping to use on third party record update operation
    //exps: copado__status__c => Object
    public Map<String,String> typeMap {
        get{
            if(null == typeMap){
                typeMap = CopadoCCMutilities.returnTargetTypeMap(pId,' and Exclude_from_tpu__c = false');
            }
            return typeMap;
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
     * Updates single record based on external Id on Jira.
     * This method will be triggered by the SendUpdatedValues2TP Process Builder Flow on User Story change criteria (customizable in the flow).
     *
     * @param usItem
     */
    public void updateRecord(copado__User_Story__c usItem){
        pId = usItem.copado__Project__c;
        projectExtId = usItem.copado__Project__r.Project_External_Id__c;
        namedCredential = usItem.copado__Project__r.Copado_Integration_Setting__r.Named_Credential__c;
        Id usId = usItem.Id;
        sObject cUserStory = database.query('SELECT '+queryFields+',External_Id__c,Enable_Logs__c FROM copado__User_Story__c WHERE Id=:usId');
        String finalJson = JsonTemplateOuter;
        for(String s:fieldMap.keyset()){
            if(null != cUserStory.get(s) && fieldMap.get(s) != 'status'){
                finalJson += String.format((typeMap.get(s) == 'object' ? JsonTemplateInnerObject : (typeMap.get(s) == 'integer' ? JsonTemplateInnerInteger : JsonTemplateInnerString)), new List<String>{fieldMap.get(s), String.escapeSingleQuotes(String.valueOf(cUserStory.get(s)))}) + ',';
            }
        }
        //callout body to update Jira record which is created from field mappings under related project and current field values
        finalJson = CopadoCCMutilities.replaceFromCurly(finalJson.substring(0,finalJson.length()-1) + '}}');
        String responseText = CopadoCCMutilities.MakeCallout(namedCredential,'','',String.format(updateParameter4TransitionString,new List<String>{(String)cUserStory.get('External_Id__c')}),'',new List<String>{contentTypeHeader},Method.GET,null,cUserStory,null);
        //Jira status update on a different method, since status is a state, not a field on Jira
        updateStatus(responseText,cUserStory);

        //callout for field update
        String responseTextFields = CopadoCCMutilities.MakeCallout(namedCredential,'','',String.format(updateParameterString,new List<String>{(String)cUserStory.get('External_Id__c')}),'',new List<String>{contentTypeHeader},Method.PUT,finalJson,cUserStory,null);
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
        pid = selectedProject.id;
        projectExtId = selectedProject.Project_External_Id__c;
        namedCredential = selectedProject.Copado_Integration_Setting__r.Named_Credential__c;

        if(String.isNotBlank(selectedProject.JQL_Extended_Filter__c)){
            if(selectedProject.JQL_Extended_Filter__c.length() >= 3) {
                if (selectedProject.JQL_Extended_Filter__c.toLowercase().replace(' ', '').substring(0, 3) != 'and') jqlExtFilter = ' AND ';
                jqlExtFilter += selectedProject.JQL_Extended_Filter__c;
                jqlExtFilter = jqlExtFilter.replace(' ', '%20');
            }
        }

        Integer startIndex = 0;
        Boolean shouldContinue = true;
        Integer total;
        //Gets issues via JQR
        while(shouldContinue) {
            String responseText = CopadoCCMutilities.MakeCallout(namedCredential, '', projectExtId+jqlExtFilter, authQueryPath, '&startAt=' + startIndex, new List<String>{
                    contentTypeHeader
            }, Method.GET, null, null, selectedProject);
            Map<String, Object> results = (Map<String, Object>) JSON.deserializeUntyped(responseText);
            //Pagination variables, Jira fetch is limited to 50 records by default
            total = Integer.valueOf(results.get('total'));
            startIndex = Integer.valueOf(results.get('startAt'));
            List<Object> issues = (List<Object>) results.get('issues');
            Map<String, String> keyValuepairTempMap;
            for (Object issue : issues) {
                keyValuepairTempMap = new Map<String, String>();
                Map<String, Object> currentIssue = (Map<String, Object>) issue;
                //Below three rows are in use for look up and external id purpose
                keyValuepairTempMap.put('key', (String) currentIssue.get('key'));
                keyValuepairTempMap.put('id', (String) currentIssue.get('id'));
                keyValuepairTempMap.put('projectid', pid);
                if (null != currentIssue.get('fields')) {
                    Map<String, Object> fields = (Map<String, Object>) currentIssue.get('fields');
                    for (String cf : fields.keySet()) {
                        //Prepares values from String
                        if (fields.get(cf) instanceof String || fields.get(cf) instanceof Integer || fields.get(cf) instanceof Decimal || fields.get(cf) instanceof Double || fields.get(cf) == null) {
                            keyValuepairTempMap.put(cf, String.valueOf(fields.get(cf)));
                        }
                        //Prepares values from Json Object
                        else if (fields.get(cf) instanceof Map<String, Object>) {
                            Map<String, Object> tempObject = (Map<String, Object>) fields.get(cf);
                            if (null != tempObject.get('emailAddress')) {
                                //Fills up user look up fields, if email address in use on Third Party Platform matches any of the email addresses on current salesforce org.
                                String cuEmail = (String) tempObject.get('emailAddress');
                                if (cf == 'assignee' && CopadoCCMutilities.userMap.containsKey(cuEmail)) {
                                    keyValuepairTempMap.put('developer', CopadoCCMutilities.userMap.get(cuEmail));
                                } else keyValuepairTempMap.put(cf, (String) tempObject.get('emailAddress'));
                            } else if (null != tempObject.get('name')) {
                                keyValuepairTempMap.put(cf, (String) tempObject.get('name'));
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
        CopadoCCMutilities.createLogRecords();
        //Returns list to executeUserStoryUpsert batch class
        return this.userStoryList;
    }

    /**
     * Updates Jira fields
     *
     * @param responseText
     * @param cUserStory
     */
    public void updateStatus(String responseText, sObject cUserStory){
        String statusfinalJson = '';
        JSONParser parser = JSON.createParser(responseText);
        //Wrapper class direct parse
        TransitionWrapper transitionWrapperItem = (TransitionWrapper)parser.readValueAs(TransitionWrapper.class);
        String currentStatusValue = (String)cUserStory.get('copado__Status__c');
        Boolean calloutFlag = false;
        for(Transitions tw:transitionWrapperItem.Transitions){
            //Checks if the current status is available on Jira workflow, if not, does not do the callout
            if(tw.name.toLowerCase() == currentStatusValue.toLowerCase()){
                statusfinalJson = CopadoCCMutilities.replaceFromCurly(String.format(transitionTemplate,new List<String>{tw.id}));
                calloutFlag = true;
                break;
            }
        }
        if(calloutFlag) CopadoCCMutilities.MakeCallout(namedCredential,'','',String.format(updateParameter4TransitionString,new List<String>{(String)cUserStory.get('External_Id__c')}),'',new List<String>{contentTypeHeader},Method.POST,statusfinalJson,cUserStory,null);
    }

    /**
     * Wrapper classes for direct casting of Transition Callout response
     */
    public class TransitionWrapper {
        public List<Transitions> Transitions;
    }
    public class Transitions {
        public String id;
        public String name;
    }
}