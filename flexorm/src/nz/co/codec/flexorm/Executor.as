package nz.co.codec.flexorm
{
    import mx.rpc.IResponder;

    public class Executor implements IExecutor
    {
        protected var _responder:IResponder;

        protected var _response:Object = null;

        protected var lastResult:Object = null;

        protected var childCount:int = 0;

        protected var q:Array = [];

        protected var _debugLevel:int;

        private var _id:int = 0;

        private var _label:String;

        private var _level:int;

        public function Executor(label:String, debugLevel:int, level:int)
        {
            _label = label;
            _debugLevel = debugLevel;
            _level = level;
        }

        public function get label():String
        {
            return getIndent() + _label;
        }

        public function getIndent():String
        {
            var indent:String = "";
            for (var i:int = 0; i < _level; i++)
            {
                indent += "    ";
            }
            return indent;
        }

        public function branchBlocking(label:String=null):BlockingExecutor
        {
            var executor:BlockingExecutor = new BlockingExecutor(label, _debugLevel, _level + 1);
            addCommand(executor, label);
            return executor;
        }

        public function branchNonBlocking(label:String=null):NonBlockingExecutor
        {
            var executor:NonBlockingExecutor = new NonBlockingExecutor(label, _debugLevel, _level + 1);
            addCommand(executor, label);
            return executor;
        }

        // abstract
        public function execute():void { }

        public function addCommand(value:ICommand, label:String=null):void
        {
            childCount++;
            q.push({ executable: value, label: label });
        }

        public function addFunction(value:Function, label:String=null):void
        {
            childCount++;
            q.push({ executable: value, label: label });
        }

        public function setResponder(value:IResponder):void
        {
            _responder = value;
        }

        public function get parent():IExecutor
        {
            return (_responder is IExecutor)? IExecutor(_responder) : null;
        }

        public function set response(value:Object):void
        {
            _response = value;
        }

        public function get response():Object
        {
            return _response;
        }

        public function set id(value:int):void
        {
            _id = value;
        }

        public function get id():int
        {
            return _id;
        }

        // abstract
        public function result(data:Object):void { }

        public function fault(info:Object):void
        {
            _responder.fault(info);
        }

    }
}