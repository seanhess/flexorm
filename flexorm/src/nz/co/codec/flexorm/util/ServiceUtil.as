package nz.co.codec.flexorm.util
{
    import mx.rpc.AsyncToken;
    import mx.rpc.IResponder;
    import mx.rpc.http.HTTPService;

    public class ServiceUtil
    {
        public static function send(
            url:String,
            responder:IResponder = null,
            method:String = null,
            request:Object = null,
            credentials:Object = null,
            sendXML:Boolean = false,
            resultFormat:String = "e4x",
            useProxy:Boolean = false):void
        {
            var service:HTTPService = new HTTPService();
            service.url = url;
            service.contentType = sendXML?
                "application/xml" : "application/x-www-form-urlencoded";
            service.resultFormat = resultFormat;
            if (method == null)
            {
                service.method = (request == null)? HTTPMethod.GET : HTTPMethod.POST;
            }
            else if ((method == HTTPMethod.PUT) || (method == HTTPMethod.DELETE))
            {
                service.method = HTTPMethod.POST;
                if (request == null)
                {
                    request = new Object();
                }
                request["_method"] = method;
            }
            else
            {
                service.method = method;
            }
            service.request = request;
            if (credentials)
            {
                service.setCredentials(credentials.username, credentials.password);
            }
            service.useProxy = useProxy;
            var call:AsyncToken = service.send();
            if (responder)
            {
                call.addResponder(responder);
            }
        }

    }
}