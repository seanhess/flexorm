package nz.co.codec.flexorm
{
    import flash.utils.getQualifiedClassName;

    public class BlockingExecutor extends Executor
    {
        private var _finalHandler:Function;

        public function BlockingExecutor()
        {
            super();
        }

        public function addFunction(fn:Function):void
        {
            childCount++;
            q.push(fn);
        }

        public function set finalHandler(value:Function):void
        {
            _finalHandler = value;
        }

        override public function execute():void
        {
            if (q.length == 0)
            {
                if (_finalHandler != null)
                {
                    _finalHandler(data);
                }
//                if (debugLevel > 0)
//                {
//                    trace("<< " + getQualifiedClassName(data));
//                    trace(data);
//                }
                _responder.result(new EntityEvent(data));
            }
            else
            {
                var executable:Object = q.shift();
                if (executable is ICommand)
                {
                    var command:ICommand = ICommand(executable);
                    command.responder = this;
                    command.execute();
                }
                else if (executable is Function)
                {
                    executable(lastResult);
                    result(lastResult);
                }
            }
        }

        override public function result(data:Object):void
        {
            lastResult = data;
            execute();
        }

    }
}