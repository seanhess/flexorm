package nz.co.codec.flexorm
{
    public class NonBlockingExecutor extends Executor
    {
        public function NonBlockingExecutor(label:String=null, debugLevel:int=0, level:int=0)
        {
            super(label? "NonBlockingExecutor::" + label : null, debugLevel, level);
        }

        override public function execute():void
        {
            if (q.length == 0)
            {
                _responder.result(new EntityEvent(_response));
            }
            else
            {
                for each(var step:Object in q)
                {
                    if (step.executable is ICommand)
                    {
                        var command:ICommand = ICommand(step.executable);
                        command.setResponder(this);
                        if (_debugLevel > 0 && step.label)
                            trace(label + " executing command " + step.label);

                        command.execute();
                    }
                    else if (step.executable is Function)
                    {
                        if (_debugLevel > 0 && step.label)
                            trace(label + " executing function " + step.label);

                        step.executable(lastResult);
                        result(lastResult);
                    }
                }
            }
        }

        override public function result(data:Object):void
        {
            lastResult = data;
            if (--childCount == 0)
            {
                _responder.result(new EntityEvent(_response));
            }
        }

    }
}