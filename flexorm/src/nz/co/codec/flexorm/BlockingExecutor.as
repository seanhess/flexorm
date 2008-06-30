package nz.co.codec.flexorm
{
    public class BlockingExecutor extends Executor
    {
        public function BlockingExecutor(label:String=null, debugLevel:int=0, level:int=0)
        {
            super(label? "BlockingExecutor::" + label : null, debugLevel, level);
        }

        override public function execute():void
        {
            if (q.length == 0)
            {
                _responder.result(new EntityEvent(_response));
            }
            else
            {
                var step:Object = q.shift();
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

        override public function result(data:Object):void
        {
            lastResult = data;
            execute();
        }

    }
}