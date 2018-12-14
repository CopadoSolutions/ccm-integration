/**
 * Utilities class for CCM Integrations.
 *
 * @author Ümit Can Uçkan
 * @version 1.0
 * @since CCM Integrations 1.0
 */
public with sharing class CopadoCCMutilities {
    //callout log list to be inserted as a final action
    public static List<Callout_Log__c> callOutLogList2Insert {
        get {
            if(callOutLogList2Insert == null){
                callOutLogList2Insert = new List<Callout_Log__c>();
            }
            return callOutLogList2Insert;
        }
        set;
    }

    /**
     * HTTP method based on a named credential and current parameters
     * Project and UserStory are required parameters for log creation
     *
     * @param namedCredential
     * @param firstParam
     * @param secondParam
     * @param firstUrlpart
     * @param secondUrlpart
     * @param additionalHeader
     * @param methodType
     * @param bodyParam
     * @param userStory
     * @param project
     *
     * @return
     */
    public static String MakeCallout(String namedCredential,String firstParam,String secondParam,String firstUrlpart,String secondUrlpart,
            List<String> additionalHeader,Method methodType,String bodyParam,sObject userStory,sObject project){
        HttpRequest req = new HttpRequest();
        //exp: callout: endpoint + projectExternalId + '/_apis/wit/wiql/' + workspaceId +'?api-version=4.1';
        req.setEndpoint('callout:'+namedCredential+'/'+firstParam+firstUrlpart+secondParam+secondUrlpart);
        for(String ahItem:additionalHeader) {
            req.setHeader(ahItem.split(':')[0], ahItem.split(':')[1]);
        }
        req.setMethod(String.valueOf(methodType));
        if(String.isNotBlank(bodyParam)) {
            req.setBody(bodyParam);
        }
        Http http = new Http();
        HTTPResponse res = http.send(req);
        if(userStory != null && (Boolean)userStory.get('Enable_Logs__c')){
            callOutLogList2Insert.add(new Callout_Log__c(Response_Body__c=res.getBody(),Status__c=res.getStatus(),Status_Code__c=String.valueOf(res.getStatusCode()),User_Story__c = (String)userStory.get('id')));
        }
        else if(null != project && (Boolean)project.get('ENABLE_Logs__c')){
            callOutLogList2Insert.add(new Callout_Log__c(Response_Body__c=res.getBody(),Status__c=res.getStatus(),Status_Code__c=String.valueOf(res.getStatusCode()),project__c = (String)project.get('id')));
        }
        System.debug('res.getBody()==> '+res.getBody());
        return res.getBody();
    }
    //Map to use on dynamic cast logic
    public static Map<String, Schema.SObjectField> M;
    static {
        M = Schema.SObjectType.copado__User_Story__c.fields.getMap();
    }
    //casts value based on the current sObject field
    public static Object returnCastedValue(Object param,String fname){
        Schema.SObjectField field = M.get(fname);
        String FldType = String.valueOf(field.getDescribe().getType()).toLowerCase();
        if (FldType == 'textarea' || FldType == 'picklist' || fldType == 'reference') {
            FldType = 'string';
        }
        if(FldType == 'boolean')            return Boolean.valueOf(param);
        if(FldType == 'string')             return String.valueOf(param);
        if(FldType == 'blob')               return (Blob)param;
        if(FldType == 'date')               return Date.valueOf(param);
        if(FldType == 'datetime')           return Datetime.valueOf(param);
        if(FldType == 'time')               return (Time)param;
        if(FldType == 'integer')            return Integer.valueOf(param);
        if(FldType == 'long')               return (Long)param;
        if(FldType == 'decimal')            return (Decimal)param;
        if(FldType == 'double')             return Double.valueOf(param);
        return null;
    }
    //usermap to match lookup values via third party users' mail addresses
    public static final Map<String,Id> userMap;
    static{
        userMap = new Map<String,id>();
        for(User u:[SELECT Id,Email FROM User WHERE IsActive = true AND Email != null]){
            userMap.put(u.Email,u.Id);
        }
    }
    //Field mapping values between salesforce and third party platform fields under related project
    public static Map<String,String> returnFieldMap(id pid,String additionalWhereClause){
        Map<String,String> fieldMap;
        if(null == fieldMap){
            fieldMap = new Map<String,String>();
            for(Field_Mapping__c fm:database.query('SELECT Salesforce_Field_Name__c, Third_Party_Field_Name__c FROM Field_Mapping__c WHERE project__c =: pid ' + additionalWhereClause)){
                fieldMap.put(fm.Salesforce_Field_Name__c.toLowerCase(),fm.Third_Party_Field_Name__c.toLowerCase());
            }
        }
        return fieldMap;
    }
    //returns a map with sf field api name to target field type, (if the target field on the third party program expect String or a json Object as a value **** defined by "target field type" field on the field mapping Object ****)
    public static Map<String,String> returnTargetTypeMap(id pid,String additionalWhereClause){
        Map<String,String> fieldMap;
        if(null == fieldMap){
            fieldMap = new Map<String,String>();
            for(Field_Mapping__c fm:database.query('SELECT Salesforce_Field_Name__c, Third_Party_Field_Name__c, Target_Field_Type__c FROM Field_Mapping__c WHERE project__c =: pid ' + additionalWhereClause)){
                fieldMap.put(fm.Salesforce_Field_Name__c.toLowerCase(),(String.isBlank(fm.Target_Field_Type__c) ? '' : fm.Target_Field_Type__c.toLowerCase()));
            }
        }
        return fieldMap;
    }
    //Escapes undesired characters in the returned JSON
    public static String escapeInvalidChars(String responseText){
        responseText = String.escapeSingleQuotes(responseText);
        responseText = responseText.escapeHTML4();
        responseText = responseText.replace('{&quot;','{"');
        responseText = responseText.replace('&quot;:&quot;','":"');
        responseText = responseText.replace('&quot;,&quot;','","');
        responseText = responseText.replace('&quot;:','":');
        responseText = responseText.replace(',&quot;',',"');
        responseText = responseText.replace('&quot;}','"}');
        responseText = responseText.replace('&amp;','&');
        responseText = responseText.replace('\b','\\b');
        responseText = responseText.replace('\n','\\n');
        responseText = responseText.replace('\t','\\t');
        responseText = responseText.replace('\r','\\r');
        responseText = responseText.replace('\\','\\\\');
        return responseText;
    }
    public static String replaceFromCurly(String strwcurly){
        return strwcurly.replace('lcurly','{').replace('rcurly','}');
    }
    //method to create logs under related user story or project record based on the step of the integration after all callouts are done
    public static void createLogRecords(){
        if(callOutLogList2Insert.size() > 0) {
            database.insert(callOutLogList2Insert, false);
        }
    }
}
