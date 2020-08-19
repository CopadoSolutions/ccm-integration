# Copado Change Management Integrations

Copado Solutions can integrate your external project management systems with Copado maintaining a bi-directional synchronization of your items between Copado Change Management and your external provider, such as Jira or Azure DevOps (formerly known as VSTS). This repository will hold the base layer of the integration code that may be extended by the community.

You can see the related documentation: https://docs.copa.do/article/rmpc3lyhfd-copado-change-management-integrations

The latest version supports JIRA and Azure DevOps (formerly known as VSTS).
If your provider is not one of these, check out this other repository: https://github.com/CopadoSolutions/CopadoIntegrations


# Copado Change Management Integrations v1.11 update (08-11-2020)
- KI-00251 fix on JIRA side : When syncing user stories from Jira, if the callout logs generated are too big and they exceed the max number of characters in the Response Body field, the Callout Log record is not created in the project.

**Upgrade instructions**: Get the following components from the master branch of this repository into your Copado CCM Integrations Org.
```
JIRAIntegration class
```
# Copado Change Management Integrations v1.10 update (12-14-2018)
- Added escapeInvalidChars method in CopadoCCMutilities class for unexpected, unescaped characters and applied on VSTSIntegration class 

**Upgrade instructions**: Get the following components from the master branch of this repository into your Copado CCM Integrations Org.
```
CopadoCCMutilities class
VSTSIntegration class
```

# Copado Change Management Integrations v1.9 update (12-03-2018)
- Added object type response handling functionality for Azure DevOps side for JSON response on "fields" level to fix "Illegal value for primitive" issue. 

**Upgrade instructions**: Get the following components from the master branch of this repository into your Copado CCM Integrations Org.
```
VSTSIntegration class
```

# Copado Change Management Integrations v1.6 update (07-31-2018)
- Added Azure DevOps callout pagination functionality for too many records.

**Upgrade instructions**: Get the following components from the master branch of this repository into your Copado CCM Integrations Org.
```
VSTSIntegration class
```

# Copado Change Management Integrations v1.3 update (07-02-2018)
- Added support for external Integers migration.
- Added support for JQL extended queries in Jira.

**Upgrade instructions**: Get the following components from the master branch of this repository into your Copado CCM Integrations Org.
```
JQL_Extended_Filter__c custom field
JiraIntegration class
Utilities class
ScheduleUserStoryFetch class
```


# How does it work?
Copado Solutions has built the authentication module as well as the framework for retrieving user stories and inserting these into the Copado sObject called, "User Story" and synchronizing them with the external provider when changes are detected.  The field mapping is also handled by the integration process. Both, the data being queried from the data source as well as the mapping, can be modified by users depending on their needs.  

We have commented the code with instructions to help with the customization process.

The code and all the components are contained in an unmanaged package in Salesforce and available within this repository as a open source project.

Installation instructions can be found below.

# Installation instructions
To install the application, use one of the below URLs:
- Production/Developer orgs: https://login.salesforce.com/packaging/installPackage.apexp?p0=04t1r000000b6k0
- Sandbox orgs: https://test.salesforce.com/packaging/installPackage.apexp?p0=04t1r000000b6k0

# Getting started with Copado Change Management Integrations
In order to customize your integration, follow these steps:

1) Create a Named Credentials record in Setup > Security > Named Credentials.
Here, you will personalize your credentials with the authorization to the external system. To do that, create a new record for the Named Credentials, provide a Name, the EndPoint URL and the fields for basic authentication.

- A Jira endpoint might look as follows: https://COMPANY_DOMAIN_NAME.atlassian.net/rest/api/2/

- The Azure DevOps URL will be as follows https://dev.azure.com/COMPANY_DOMAIN_NAME/

Note: If your company have setup the integration before VSTS was rebranded to Azure, the old URL endpoint https://COMPANY_DOMAIN_NAME.visualstudio.com/ is still usable.

Note: For Azure DevOps, it is required to provide your personal access token instead of the password. Otherwise, it will not return the content from the external provider. To generate your access token go to: User > Security > Access Token.
For JIRA, it is required to provide your api token instead of the password,Otherwise, it will not return the content from the external provider. To generate your access token go to: https://id.atlassian.com/manage-profile/security/api-tokens.


2) In Copado Integration Settings tab, create a new record with your external provider. During the record creation, provide a name (Copado Integration Setting Name field), select a provider from the picklist (External System field) and type the Named Credential you have just created (Named Credential field). It is very important to type the Named Credentials correctly since Named Credentials cannot be located through a lookup field.

3) Create a new Project to include all the User Stories that will be synchronized.
Go to Projects tab in Copado Change Management application and create a Project for your User Stories. Provide a Name for it, your external provider’s Project Id (Project External Id field), provide also Workspace Id for Azure DevOps using the Query Id (found in the address bar as a parameter - a VSTS Query Id might look as follows: bd7cae54-f1d1-4687-b313-0c64ecdfe731)  and select the Copado Integration Setting you have just created for your external provider.

4) Set the fields mappings for the integration.
Within the Field Mapping related list of your integration project, you can add as many field mappings as you wish. 

Mandatory fields:
- Salesforce Field Name: Name of the User Story field in Salesforce.
- Third Party Field Name: Name of the external provider field which should be mapped with the user story field in Salesforce.
- Project: Project where the User Stories belong.

Optional fields:
- Exclude From Third Party Update: External provider’s fields you do not want to be updated with Salesforce fields values.
- Exclude From Salesforce Update: Salesforce fields you do not want to be updated with the external fields values.
- Target Field Type. String or object types. This type is used for the JSON file creation.

### Mandatory Field Mapping records for both JIRA and Azure DevOps:
      Salesforce_Field_Name__c | Third_Party_Field_Name__c | Exclude_from_tpu__c
-       copado__Project__c 		         projectId 		                true
-       External_Id__c        	  	      id                 true(false for Azure DevOps)

## Fields mapping by default
In this repository you will find two files to be uploaded to your Salesforce Org. They contain a set of fields by default for both providers for an easy and quick setup. 
These files are:
JIRA_Default_Field_Mappings.csv
VSTS_Default_Field_Mappings.csv

## Important Note related to Field Mappings
To be able to Map some values (e.g. relationship type fields) between the Third Party Platform and Salesforce, you need to modify one of the related classes (JIRAIntegration, VSTSIntegration) on Salesforce side. For instance, we use assignee's email on JIRA to match user email on Salesforce and fill developer look-up on User Story object. On the Field Mappings record, we use developer keyword for Third Party Field Name -which does not exist on JIRA-. You can see code examples on those classes related to this implementation and add your own code to match additional fields which requires custom development.

We also have two fields which called Exclude from Third Party update and Exclude from Salesforce update on Field Mappings object to give you the controlling option on which platform you want to keep as a master. For instance, if you want User Story status to be updated only from Third Party Platform to Salesforce direction, you need to check Exclude from Third Party update field on the Status field mapping record to exclude this value from Third Party update callout. 
As you can see from our Default Field Mappings csv files, it is also required on external Id type fields'(e.g. key, id ) Field Mapping configuration. Since, key and id fields are not editable on JIRA, we excluded them from Third Party update callout via checking Exclude from Third Party update fields on related Field Mappings records.

## New Apex Class - ScheduleUserStoryFetch 
The new class ScheduleUserStoryFetch has been created to perform a bulk from the external provider to Salesforce. Depending on the configuration of its cron expression, it will carry out the bulk operation periodically. It will retrieve all the mapped fields and will update the Salesforce fields with the external data.

Sample on how to schedule the fetch process:
```
//Parameters to be changed
Integer timeIntervalInSeconds = 600;  //e.g. 600 seconds = 10 minutes
String myProjectRecordId = 'project_id_must_be_here';

//Now let's schedule the project sync
ScheduleUserStoryFetch scheduledClass = new ScheduleUserStoryFetch (myProjectRecordId);
String cronExpression = Datetime.now().addSeconds(timeIntervalInSeconds).format('s m H d M ? yyyy');
String jobID = system.schedule('Scheduled User Story Sync for '+ myProjectRecordId, cronExpression, scheduledClass);
```

## New Process Builder Flow - SendUpdatedValues2TP
A new Process Builder Flow has been created for updating changes in User Stories on the external provider. It is executed every time a change in a User Story is detected and will send the modified fields to the external object fields.

This Process Builder Flow is included as a template, and Active. Criteria may be modified or extended as per the customer requirements by versioning this Process Builder Flow. **Deactivating this Process Builder Flow may take the code coverage under deployment threshold.**

## Callout Logs
On the User Story and the Project, there is a checkbox labelled as “Enable Logs” to add to the US or Project layout the logs created from that moment on. It is unchecked by default.
**If you are fetching more then 500 records from third party platform, we recommend you to disable this checkbox based on heap size consideration.**

Jira sends 204 code when Salesforce sends a record and the operation was successful (instead of the usual 200 code). 

Some considerations when reading the logs:
- For each operation (Salesforce update to Jira), Jira sends 3 callouts. 
- For each operation (Salesforce update to Azure DevOps), Azure DevOps sends 1 call out.

The callout log records generated from Salesforce updates are tracked when flagging the Enable Logs checkbox in user story record and are stored Callout Logs user story related list.

- At fetch level, Jira performs 1 callouts.
- At fetch level, Azure DevOps performs 2 callouts.

The callout log records generated from fetching are tracked when flagging the Enable Logs checkbox in project record and are stored in the Callout Logs project related list.

This logging system was implemented to handle the characteristics of this integration (future callouts) for a better error handling.

## Best Practices recommendation
When you are integrating Copado User Stories with an external source, it is common that this external source becomes the master of some of the data being synchronized.
We highly recommend blocking in the User Story Layout as "read-only" the fields you want your external source to be the master off, and exclude the Copado field from the synchronization in the Field Mappings Object.
This resource will help avoiding sync conflicts while keeping the technical solution as simple as possible for a better maintenance and troubleshooting.

# Important Note
- To be able to update JIRA fields from Salesforce, fields you want to update must be on the layout screens.
- Go to https://yourDomain/plugins/servlet/project-config/YourprojectKey/screens, click to screen that you want to edit and add your fields to create, edit, view screens.

- If you have Jira On-Premises behind a Firewall, make sure you white list Salesforce's IP ranges since communication is done from Salesforce Organization to Jira, for more info: 
https://help.salesforce.com/articleView?id=000003652&type=1
