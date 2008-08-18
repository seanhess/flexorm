package nz.co.codec.flexorm
{
    import flash.utils.getQualifiedClassName;

    public class NonBlockingExecutor extends Executor
    {
        public function NonBlockingExecutor()
        {
            super();
        }

        override public function execute():void
        {
            if (q.length == 0)
            {
                _responder.result(new EntityEvent(data));
            }
            else
            {
                for each(var executable:Object in q)
                {
                    if (executable is ICommand)
                    {
                        var command:ICommand = ICommand(executable);
                        command.responder = this;
                        command.execute();
                    }
                }
            }
        }

        override public function result(data:Object):void
        {
            lastResult = data;
            if (--childCount == 0)
            {
//                if (debugLevel > 0)
//                {
//                    trace("<< " + getQualifiedClassName(data));
//                    trace(data);
//                }
                _responder.result(new EntityEvent(data));
            }
        }

    }
}