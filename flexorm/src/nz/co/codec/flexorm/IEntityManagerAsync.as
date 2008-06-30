package nz.co.codec.flexorm
{
    import flash.data.SQLConnection;

    import mx.rpc.IResponder;

    public interface IEntityManagerAsync
    {
        function findAll(c:Class, responder:IResponder):void;

        function load(c:Class, id:int, responder:IResponder):void;

        function loadItem(c:Class, id:int, responder:IResponder):void;

        function loadItemByCompositeKey(cls:Class, compositeKeys:Array, responder:IResponder):void;

        function save(o:Object, responder:IResponder):void;

        function remove(o:Object, responder:IResponder):void;

        function removeItem(c:Class, id:int, responder:IResponder):void;

        function markForDeletion(obj:Object, responder:IResponder):void;

        function startTransaction(responder:IResponder):void

        function endTransaction(responder:IResponder):void;

        function makePersistent(c:Class):void;

        function openAsyncConnection(dbFilename:String):void

        function set sqlConnection(value:SQLConnection):void;

        function get sqlConnection():SQLConnection;

        function set debugLevel(value:int):void;

        function get debugLevel():int;

    }
}