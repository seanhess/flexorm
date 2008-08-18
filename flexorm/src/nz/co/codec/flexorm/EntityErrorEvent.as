package nz.co.codec.flexorm
{
    import flash.events.Event;

    public class EntityErrorEvent extends Event
    {
        private var _message:String;

        private var _error:Error;

        public function EntityErrorEvent(message:String, error:Error=null, bubbles:Boolean=false, cancelable:Boolean=false)
        {
            super("entityError", bubbles, cancelable);
            _message = message;
            _error = error;
        }

        public function set message(value:String):void
        {
            _message = value;
        }

        public function get message():String
        {
            return _message;
        }

        public function get error():Error
        {
            return _error;
        }

        public function getStackTrace():String
        {
            return _error? _error.getStackTrace() : null;
        }

        override public function toString():String
        {
            return _message? _message : "unknown";
        }

    }
}