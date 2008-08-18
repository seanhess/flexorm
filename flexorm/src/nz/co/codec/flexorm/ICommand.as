package nz.co.codec.flexorm
{
    import mx.rpc.IResponder;

    public interface ICommand
    {
        function set responder(value:IResponder):void;

        function execute():void;

    }
}