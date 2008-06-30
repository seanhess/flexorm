package nz.co.codec.flexorm.util
{
    import mx.rpc.IResponder;

    import nz.co.codec.flexorm.ICommand;

    public class ServiceCommand implements ICommand, IResponder
    {
        private var _url:String;

        private var _request:Object;

        private var _method:String;

        private var _resultHandler:Function;

        private var _credentials:Object;

        private var _responder:IResponder;

        public function ServiceCommand(
            url:String,
            method:String,
            request:Object,
            resultHandler:Function=null,
            credentials:Object=null)
        {
            _url = url;
            _method = method;
            _request = request;
            _resultHandler = resultHandler;
            _credentials = credentials;
        }

        public function setResponder(value:IResponder):void
        {
            _responder = value;
        }

        public function execute():void
        {
            ServiceUtil.send(_url, this, _method, _request, _credentials);
        }

        public function result(data:Object):void
        {
            if (_resultHandler != null)
            {
                _resultHandler.call(this, data);
            }
            _responder.result(data);
        }

        public function fault(info:Object):void
        {
            _responder.fault(info);
        }

    }
}