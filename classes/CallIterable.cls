/**
 * Created by umitcanuckan on 07/06/2018.
 */


global class CallIterable implements iterable<object>{
    List<object> listObj;
    global CallIterable(List<object> listObjParam){
        this.listObj = listObjParam;
    }
    global Iterator<object> Iterator(){
        return new CustomIterable(listObj);
    }
}