package nz.co.codec.flexorm
{
    import mx.rpc.IResponder;

    public interface IExecutor extends ICommand, IResponder
    {
        function addCommand(value:ICommand, label:String=null):void;

        function get parent():IExecutor;

        function set response(value:Object):void;

        function get response():Object;

        function set id(value:int):void;

        function get id():int;

        function branchBlocking(label:String=null):BlockingExecutor;

        function branchNonBlocking(label:String=null):NonBlockingExecutor;

    }
}