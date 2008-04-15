package nz.co.codec.flexorm
{
	import flash.data.SQLConnection;
	
	import mx.collections.ArrayCollection;
	import mx.rpc.IResponder;
	
	public interface IEntityManager
	{
		function set sqlConnection(value:SQLConnection):void;
		
		function get sqlConnection():SQLConnection;
		
		function startTransaction(responder:IResponder = null):void
		
		function endTransaction():void;
		
		function makePersistent(c:Class):void;
		
		function findAll(c:Class):ArrayCollection;
		
		function loadItem(c:Class, id:int):Object;
		
		function save(o:Object):void;
		
		function remove(o:Object):void;
		
		function get debugLevel():int;
		
		function set debugLevel(value:int):void;
		
	}
}