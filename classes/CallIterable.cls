/**
 * Iterable implementation for Object.
 *
 * @author Ümit Can Uçkan
 * @version 1.0
 * @since CCM Integrations 1.0
 */
global with sharing class CallIterable implements Iterable<Object>{
    List<Object> listObj;
    global CallIterable(List<Object> listObjParam){
        this.listObj = listObjParam;
    }
    global Iterator<Object> Iterator(){
        return new CustomIterable(listObj);
    }
}