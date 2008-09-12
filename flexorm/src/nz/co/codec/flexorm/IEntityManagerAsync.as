package nz.co.codec.flexorm
{
    import flash.data.SQLConnection;

    import mx.rpc.IResponder;

    import nz.co.codec.flexorm.criteria.Criteria;

    public interface IEntityManagerAsync
    {
        function findAll(cls:Class, responder:IResponder):void;

        function createCriteria(cls:Class, responder:IResponder):void;

        function fetchCriteria(crit:Criteria, responder:IResponder):void;

        function fetchCriteriaFirstResult(crit:Criteria, responder:IResponder):void;

        function load(cls:Class, id:int, responder:IResponder):void;

        function loadItem(cls:Class, id:int, responder:IResponder):void;

        function loadItemByCompositeKey(cls:Class, keys:Array, responder:IResponder):void;

        function save(obj:Object, responder:IResponder, opt:Object=null):void;

        function remove(obj:Object, responder:IResponder):void;

        function removeItem(cls:Class, id:int, responder:IResponder):void;

        function markForDeletion(obj:Object, responder:IResponder):void;

        function startTransaction(responder:IResponder):void

        function endTransaction(responder:IResponder):void;

        function makePersistent(cls:Class):void;

        function openAsyncConnection(dbFilename:String, responder:IResponder):void

        function set sqlConnection(value:SQLConnection):void;

        function get sqlConnection():SQLConnection;

        function set debugLevel(value:int):void;

        function get debugLevel():int;

    }
}