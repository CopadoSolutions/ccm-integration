/**
 * Created by umitcanuckan on 13/06/2018.
 */

public with sharing class SyncUserStoriesController {

    public void ScheduleFetchOperationAndReturn2Project(){
        id pId = ApexPages.currentPage().getParameters().get('pid');
        ScheduleUserStoryFetch Susf = new ScheduleUserStoryFetch (pId);
        String str = Datetime.now().addSeconds(5).format('s m H d M ? yyyy');
        String jobID = system.schedule('ScheduleUserStoryFetch - ' + DateTime.Now() + '.' + math.mod(DateTime.now().getTime(), 1000), str, Susf);
    }
}