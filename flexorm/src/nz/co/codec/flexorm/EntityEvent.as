package nz.co.codec.flexorm
{
    import flash.events.Event;

    public class EntityEvent extends Event
    {
        private var _data:Object;

        public function EntityEvent(data:Object=null, bubbles:Boolean=false, cancelable:Boolean=false)
        {
            super("entityChange", bubbles, cancelable);
            _data = data;
        }

        public function get data():Object
        {
            return _data;
        }

    }
}