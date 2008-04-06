package nz.co.codec.flexorm
{
	import flash.data.SQLConnection;
	
	import mx.collections.ArrayCollection;
	
	public interface IEntityManager
	{
		function set sqlConnection(value:SQLConnection):void;
		
		function get sqlConnection():SQLConnection;
		
		function findAll(c:Class):ArrayCollection;
		
		function loadItem(c:Class, id:int):Object;
		
		function save(o:Object):void;
		
		function remove(o:Object):void;
		
		function get debugLevel():int;
		
		function set debugLevel(value:int):void;
		
	}
}