/**
 * Created by umitcanuckan on 06/06/2018.
 */

public with sharing class IntegrationFactory {
    //Creates and instance based on the type field of related project's Copado Integration Setting record
    public static IIntegration returnInstance(string type){
        //TODO: use these types on the page you will create
        if(type == 'Visual Studio Team Services'){
            IIntegration VSTSInstance = new VSTSIntegration();
            return VSTSInstance;
        }
        else if(type == 'JIRA'){
            IIntegration JIRAInstance = new JiraIntegration();
            return JIRAInstance;
        }
        else{//this is not possible as long as you do not add new values, since external type field on Copado Integration Settings object is a restricted picklist
            system.debug('You can only use JIRA or VSTS integration types!');
            return null;
        }
    }
}