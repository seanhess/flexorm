package nz.co.codec.flexorm
{
    import flash.utils.getQualifiedClassName;

    import mx.rpc.IResponder;

    public class Executor implements IExecutor
    {
        protected var childCount:int;

        protected var q:Array;

        protected var lastResult:Object;

        protected var _responder:IResponder;

        private var _workingStorage:Object;

        private var _data:Object;

        private var _id:int;

        private var _debugLevel:int;

        private var _label:String;

        public function Executor()
        {
            _workingStorage = {};
            _debugLevel = 0;
            childCount = 0;
            q = [];
        }

        public function branchBlocking():BlockingExecutor
        {
            var executor:BlockingExecutor = new BlockingExecutor();

            // reference to the same data store anywhere in the executor tree
            executor.workingStorage = _workingStorage;
            executor.debugLevel = _debugLevel;
            add(executor);
            return executor;
        }

        public function branchNonBlocking():NonBlockingExecutor
        {
            var executor:NonBlockingExecutor = new NonBlockingExecutor();

            // reference to the same data store anywhere in the executor tree
            executor.workingStorage = _workingStorage;
            executor.debugLevel = _debugLevel;
            add(executor);
            return executor;
        }

        // abstract
        public function execute():void { }

        public function add(command:ICommand, resultHandler:Function=null):void
        {
            childCount++;
            q.push(command);
            if (resultHandler != null)
            {
                childCount++;
                q.push(resultHandler);
            }
        }

        public function set responder(value:IResponder):void
        {
            _responder = value;
        }

        public function get parent():IExecutor
        {
            return (_responder is IExecutor)? IExecutor(_responder) : null;
        }

        public function setProperty(name:String, value:*):void
        {
            _workingStorage[name] = value;
        }

        public function getProperty(name:String):*
        {
            return _workingStorage[name];
        }

        internal function set workingStorage(value:Object):void
        {
            _workingStorage = value;
        }

        public function set data(value:Object):void
        {
            _data = value;
        }

        public function get data():Object
        {
            return _data;
        }

        public function set id(value:int):void
        {
            _id = value;
        }

        public function get id():int
        {
            return _id;
        }

        public function set debugLevel(value:int):void
        {
            _debugLevel = value;
        }

        public function get debugLevel():int
        {
            return _debugLevel;
        }

        public function set label(value:String):void
        {
            _label = value;
        }

        public function get label():String
        {
            return _label;
        }

        // abstract
        public function result(data:Object):void { }

        public function fault(info:Object):void
        {
            trace("!! " + getQualifiedClassName(info));
            trace(info);
            _responder.fault(info);
        }

    }
}