/**
 * Mock controller for retrieving External User Stories from the Project's button.
 *
 * @author Ümit Can Uçkan
 * @version 1.0
 * @since CCM Integrations 1.0
 */
public with sharing class SyncUserStoriesController {

    public void ScheduleFetchOperationAndReturn2Project(){
        Id pId = ApexPages.currentPage().getParameters().get('pid');
        ScheduleUserStoryFetch Susf = new ScheduleUserStoryFetch (pId);
        String str = Datetime.now().addSeconds(5).format('s m H d M ? yyyy');
        String jobID = System.schedule('ScheduleUserStoryFetch - ' + DateTime.now() + '.' + Math.mod(DateTime.now().getTime(), 1000), str, Susf);
    }
}