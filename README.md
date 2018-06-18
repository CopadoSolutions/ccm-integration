# Copado Change Management Integrations

Copado Solutions can integrate your external project management systems with Copado maintaining a bi-directional synchronization of your items between Copado Change Management and your external provider, such as Jira or Microsoft VSTS. This repository will hold the base layer of the integration code that may be extended by the community.

The latest version supports JIRA and Microsoft VSTS.
If your provider is not one of these, check out this other repository: https://github.com/CopadoSolutions/CopadoIntegrations

# How does it work?
Copado Solutions has built the authentication module as well as the framework for retrieving user stories and inserting these into the Copado sObject called, "User Story" and synchronizing them with the external provider when changes are detected.  The field mapping is also handled by the integration process.  Both, the data being queried from the data source as well as the mapping, can be modified by users depending on their needs.  

We have commented the code with instructions to help with the customization process.

The code and all the components are contained in an unmanaged package in Salesforce and available within this repository as a open source project.

Installation instructions can be found below.

# Installation instructions
To install the application, use one of the below URLs:
- Production/Developer orgs:  -----------------------------------------
- Sandbox orgs: --------------------------------------

# Getting started with Copado Change Management Integrations

In order to customize your integration, follow these steps:

1) Create a Named Credentials record in Setup > Security > Named Credentials.
Here, you will personalize your credentials with the authorization to the external system. To do that, create a new record for the named credentials, provide a name, the EndPoint URL and the fields for basic authentication.

- A Jira endpoint might look as follows: https://COMPANY_DOMAIN_NAME.atlassian.net/rest/api/2/

- A Microsoft VSTS endpoint might look as follows: https://COMPANY_DOMAIN_NAME.visualstudio.com/

Note: For Microsoft VSTS, it is required to provide your personal access token instead of the password. Otherwise, it will not return the content from the external provider. To generate your access token go to: User > Security > Access Token.


2) In Copado Integration Settings tab, create a new record with your external provider. During the record creation, provide a name (Copado Integration Setting Name field), select a provider from the picklist (External System field) and type the Named Credential you have just created (Named Credential field). It is very important to type the Named Credentials correctly since Named Credentials cannot be located through a lookup field.

3) Create a new Project to include all the user stories that will be synchronized.
Go to Projects tab in Copado Change Management application and create a project for your user stories. Provide a name for it, your external provider’s project id (Project External Id field), provide also Workspace Id for Microsoft VSTS using the Query Id (found in the address bar as a parameter)  and select the Copado Integration Setting you have just created for your external provider.

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

### Mandatory Field Mapping records for both JIRA and VSTS:

#### Salesforce_Field_Name__c  : copado__Project__c

Third_Party_Field_Name__c : projectId     

Exclude_from_tpu__c       : true    	    

Salesforce_Field_Name__c  : External_Id__c

Third_Party_Field_Name__c : id     		

Exclude_from_tpu__c       : true(false for VSTS)

## New Apex Class - ScheduleUserStoryFetch 
The new class ScheduleUserStoryFetch has been created to perform a bulk from the external provider to Salesforce. Depending on the configuration of its cron expression, it will carry out the bulk operation periodically. It will retrieve all the mapped fields and will update the Salesforce fields with the external data.

## New Process Builder Flow - SendUpdatedValues2TP
A new Process Builder Flow has been created for updating changes in User Stories on the external provider. It is executed every time a change in a User Story is detected and will send the modified fields to the external object fields.

This Process Builder Flow is included as a template, but deactivated. Activating it will start sending updates to the External System on User Story Status change. Criteria may be modified or extended as per the customer requirements.

## Fields mapping by default
In this repository you will find 2 files to be uploaded to your Salesforce Org. They contain a set of fields by default for both providers. 
These files are:
JIRA Default Field Mappings.numbers
VSTS Default Field Mappings.numbers


## Callout Logs
On the User Story and the Project, there is a checkbox labelled as “Enable Logs” to add to the US or Project layout the logs created from that moment on. It is unchecked by default.

Jira sends 204 code when Salesforce sends a record and the operation was successful (instead of the usual 200 code). 

Some considerations when reading the logs:
- For each operation, Jira sends 3 callouts.
- For each operation, VSTS sends 1 call out.
- At fetch level, Jira performs 1 callouts.
- At fetch level, VSTS performs 2 callouts.

This logging system was implemented to handle the characteristics of this integration (future callouts) for a better error handling.





