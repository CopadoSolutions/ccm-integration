/**
 * Integration Interface.
 *
 * @author Ümit Can Uçkan
 * @version 1.0
 * @since CCM Integrations 1.0
 */
public interface IIntegration {
    List<Map<String,String>> fetchRecords(copado__Project__c selectedProject);
    void updateRecord(copado__User_Story__c usItem);
}