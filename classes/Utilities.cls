/**
 * Created by umitcanuckan on 06/06/2018.
 */
//Helper methods
public with sharing class Utilities {
    //callout log list to be inserted as a final action
    public static List<Callout_Log__c> callOutLogList2Insert {get{
        if(null == callOutLogList2Insert){
            callOutLogList2Insert = new List<callout_log__c>();
        }
        return callOutLogList2Insert;
    }set;}
    //http method based on named credential and current parameters
    //projectid and userid parameter are to use on log creation
    public static string MakeCallout(string namedCredential,string firstParam,string secondParam,string firstUrlpart,string secondUrlpart,List<string> additionalHeader,Method methodType,string bodyParam,sObject userStory,sObject project){
        HttpRequest req = new HttpRequest();
        //exp: callout: endpoint + projectExternalId + '/_apis/wit/wiql/' + workspaceId +'?api-version=4.1';
        req.setEndpoint('callout:'+namedCredential+'/'+firstParam+firstUrlpart+secondParam+secondUrlpart);
        for(string ahItem:additionalHeader) {
            req.setHeader(ahItem.split(':')[0], ahItem.split(':')[1]);
        }
        req.setMethod(string.valueOf(methodType));
        if(string.isNotBlank(bodyParam)) {
            req.setBody(bodyParam);
        }
        Http http = new Http();
        HTTPResponse res = http.send(req);
        if(null != userStory && (boolean)userStory.get('enable_logs__c')){
            callOutLogList2Insert.add(new Callout_Log__c(Response_Body__c=res.getBody(),Status__c=res.getStatus(),status_code__c=string.valueof(res.getStatusCode()),User_Story__c = (string)userStory.get('id')));
        }
        else if(null != project && (boolean)project.get('enable_logs__c')){
            callOutLogList2Insert.add(new Callout_Log__c(Response_Body__c=res.getBody(),Status__c=res.getStatus(),status_code__c=string.valueof(res.getStatusCode()),project__c = (string)project.get('id')));
        }
        system.debug('res.getBody()==> '+res.getBody());
        return res.getBody();
    }
    //Map to use on dynamic cast logic
    public static Map<String, Schema.SObjectField> M;
    static {
        M = Schema.SObjectType.copado__User_Story__c.fields.getMap();
    }
    //casts value based on the current sObject field
    public static object returnCastedValue(object param,string fname){
        Schema.SObjectField field = M.get(fname);
        string FldType = string.valueOf(field.getDescribe().getType()).toLowerCase();
        if (FldType == 'textarea' || FldType == 'picklist' || fldType == 'reference') {
            FldType = 'string';
        }
        system.debug('FldType===> '+FldType);
        if(FldType == 'boolean')            return boolean.valueOf(param);
        if(FldType == 'string')             return String.valueOf(param);
        if(FldType == 'blob')               return (blob)param;
        if(FldType == 'date')               return Date.valueOf(param);
        if(FldType == 'datetime')           return Datetime.valueOf(param);
        if(FldType == 'time')               return (time)param;
        if(FldType == 'integer')            return Integer.valueOf(param);
        if(FldType == 'long')               return (long)param;
        if(FldType == 'decimal')            return (decimal)param;
        if(FldType == 'double')             return Double.valueOf(param);
        return null;
    }
    //usermap to match lookup values via third party users' mail addresses
    public static final Map<string,id> userMap;
    static{
        userMap = new Map<string,id>();
        for(user u:[select id,email from user]){
            userMap.put(u.email,u.id);
        }
    }
    //Field mapping values between salesforce and third party platform fields under related project
    public static Map<string,string> returnFieldMap(id pid,string additionalWhereClause){
        Map<string,string> fieldMap;
        if(null == fieldMap){
            fieldMap = new Map<string,string>();
            for(Field_Mapping__c fm:database.query('select Salesforce_Field_Name__c, Third_Party_Field_Name__c from Field_Mapping__c where project__c =: pid ' + additionalWhereClause)){
                fieldMap.put(fm.Salesforce_Field_Name__c.toLowerCase(),fm.Third_Party_Field_Name__c.toLowerCase());
            }
        }
        return fieldMap;
    }
    //returns a map with sf field api name to target field type, (if the target field on the third party program expect string or a json object as a value **** defined by "target field type" field on the field mapping object ****)
    public static Map<string,string> returnTargetTypeMap(id pid,string additionalWhereClause){
        Map<string,string> fieldMap;
        if(null == fieldMap){
            fieldMap = new Map<string,string>();
            for(Field_Mapping__c fm:database.query('select Salesforce_Field_Name__c, Third_Party_Field_Name__c, Target_Field_Type__c from Field_Mapping__c where project__c =: pid ' + additionalWhereClause)){
                fieldMap.put(fm.Salesforce_Field_Name__c.toLowerCase(),(string.isBlank(fm.Target_Field_Type__c) ? '' : fm.Target_Field_Type__c.toLowerCase()));
            }
        }
        return fieldMap;
    }
    public static string replaceFromCurly(string strwcurly){
         return strwcurly.replace('lcurly','{').replace('rcurly','}');
    }
    //method to create logs under related user story or project record based on the step of the integration after all callouts are done
    public static void createLogRecords(){
        if(callOutLogList2Insert.size() > 0) {
            database.insert(callOutLogList2Insert, false);
        }
    }
}