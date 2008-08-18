package nz.co.codec.flexorm
{
    import flash.data.SQLConnection;

    import mx.collections.ArrayCollection;

    public interface IEntityManager
    {
        function startTransaction():void

        function endTransaction():void;

        function findAll(cls:Class):ArrayCollection;

        function load(cls:Class, id:int):Object;

        function loadItem(cls:Class, id:int):Object;

        function loadItemByCompositeKey(cls:Class, keys:Array):Object;

        function save(obj:Object, opt:Object=null):int;

        function removeItem(cls:Class, id:int):void;

        function removeItemByCompositeKey(cls:Class, keys:Array):void;

        function remove(obj:Object):void;

        function markForDeletion(obj:Object):void;

        function makePersistent(cls:Class):void;

        function openSyncConnection(dbFilename:String):void;

        function set sqlConnection(value:SQLConnection):void;

        function get sqlConnection():SQLConnection;

        function set debugLevel(value:int):void;

        function get debugLevel():int;


        // Not fully implemented ------------------------------

        function loadDynamicObject(name:String, id:int):Object;

    }
}