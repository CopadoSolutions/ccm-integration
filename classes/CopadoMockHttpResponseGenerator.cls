/**
 * Mock HTTP class to emulate and test JSON responses from External Providers' APIs
 *
 * @author Ümit Can Uçkan
 * @version 1.0
 * @since CCM Integrations 1.0
 */
@isTest
public class CopadoMockHttpResponseGenerator implements HttpCalloutMock {
    protected Integer code;
    protected String status;
    protected String bodyAsString;
    protected Blob bodyAsBlob;
    protected Map<String, String> responseHeaders;

    public CopadoMockHttpResponseGenerator(Integer code, String status, String body, Map<String, String> responseHeaders) {
        this.code = code;
        this.status = status;
        this.bodyAsString = body;
        this.bodyAsBlob = null;
        this.responseHeaders = responseHeaders;
    }

    public CopadoMockHttpResponseGenerator(Integer code, String status, Blob body, Map<String, String> responseHeaders) {
        this.code = code;
        this.status = status;
        this.bodyAsBlob = body;
        this.bodyAsString = null;
        this.responseHeaders = responseHeaders;
    }

    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse resp = new HttpResponse();
        resp.setStatusCode(code);
        resp.setStatus(status);
        if (bodyAsBlob != null) {
            resp.setBodyAsBlob(bodyAsBlob);
        } else {
            resp.setBody(bodyAsString);
        }

        if (responseHeaders != null) {
            for (String key : responseHeaders.keySet()) {
                resp.setHeader(key, responseHeaders.get(key));
            }
        }
        return resp;
    }
}
