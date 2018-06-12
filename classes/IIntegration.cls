/**
 * Created by umitcanuckan on 05/06/2018.
 */

public interface IIntegration {
    List<Map<string,string>> fetchRecords(copado__Project__c selectedProject);
    void updateRecord(copado__user_story__c usItem);
}