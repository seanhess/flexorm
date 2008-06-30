package nz.co.codec.flexorm
{
    import mx.rpc.IResponder;

    public interface ICommand
    {
        function setResponder(value:IResponder):void;

        function execute():void;

    }
}