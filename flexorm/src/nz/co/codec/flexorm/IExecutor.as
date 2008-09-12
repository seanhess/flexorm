package nz.co.codec.flexorm
{
    import mx.rpc.IResponder;

    public interface IExecutor extends ICommand, IResponder
    {
        function add(command:ICommand, resultHandler:Function=null):void;

        function get parent():IExecutor;

        function setProperty(name:String, value:*):void;

        function getProperty(name:String):*;

        function set data(value:Object):void;

        function get data():Object;

        function set id(value:*):void;

        function get id():*;

        function branchBlocking():BlockingExecutor;

        function branchNonBlocking():NonBlockingExecutor;

    }
}