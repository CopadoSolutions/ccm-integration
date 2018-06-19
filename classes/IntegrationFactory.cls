/**
 * Integration Factory class. Returns the Adapter for the selected external provider.
 *
 * @author Ümit Can Uçkan
 * @version 1.0
 * @since CCM Integrations 1.0
 */
public with sharing class IntegrationFactory {
    /**
     * Creates and instance based on the type field of related project's Copado Integration Setting record
     *
     * @param type
     *
     * @return IIntegration
     */
    public static IIntegration returnInstance(String type){
        if(type == 'Visual Studio Team Services'){
            IIntegration VSTSInstance = new VSTSIntegration();
            return VSTSInstance;
        }
        else if(type == 'JIRA'){
            IIntegration JIRAInstance = new JiraIntegration();
            return JIRAInstance;
        }
        else{
            //Customize the logic in this if and the following error message in order to support extra providers
            System.debug('You can only use JIRA or VSTS integration types!');
            return null;
        }
    }
}