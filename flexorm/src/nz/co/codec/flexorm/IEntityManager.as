package nz.co.codec.flexorm
{
    import flash.data.SQLConnection;

    import mx.collections.ArrayCollection;

    public interface IEntityManager
    {
        function findAll(cls:Class):ArrayCollection;

        function load(cls:Class, id:int):Object;

        function loadItem(cls:Class, id:int):Object;

        function loadObject(name:String, id:int):Object;

        function loadItemByCompositeKey(cls:Class, compositeKeys:Array):Object;

        function save(obj:Object, name:String=null):int;

        function remove(obj:Object):void;

        function removeItem(cls:Class, id:int):void;

        function markForDeletion(obj:Object):void;

        function startTransaction():void

        function endTransaction():void;

        function makePersistent(cls:Class):void;

        function openSyncConnection(dbFilename:String):void;

        function set sqlConnection(value:SQLConnection):void;

        function get sqlConnection():SQLConnection;

        function set debugLevel(value:int):void;

        function get debugLevel():int;

    }
}