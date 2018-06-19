/**
 * Iterable implementation for Object.
 *
 * @author Ümit Can Uçkan
 * @version 1.0
 * @since CCM Integrations 1.0
 */
global with sharing class CustomIterable implements Iterator<Object> {

    List<Object> usList { get; set; }
    Integer i { get; set; }
    Integer listSize;

    public CustomIterable(List<Object> listObj) {
        usList = listObj;
        listSize = usList.size();
        i = 0;
    }

    global Boolean hasNext() {
        if (i >= usList.size()) {
            return false;
        } else {
            return true;
        }
    }

    global Object next() {
        if (i == listSize) {
            return null;
        }
        i++;
        return usList[i - 1];
    }
}