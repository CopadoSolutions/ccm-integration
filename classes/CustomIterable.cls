/**
 * Created by umitcanuckan on 07/06/2018.
 */

global class CustomIterable implements Iterator<object>{

    List<object> usList {get; set;}
    Integer i {get; set;}
    integer listSize;

    public CustomIterable(List<object> listObj){
        usList = listObj;
        listSize = usList.size();
        i = 0;
    }

    global boolean hasNext(){
        if(i >= usList.size()) {
            return false;
        } else {
            return true;
        }
    }

    global object next(){
        if(i == listSize){return null;}
        i++;
        return usList[i-1];
    }
}