package nz.co.codec.flexorm.command
{
	import flash.data.SQLConnection;
	import flash.data.SQLStatement;
	
	public class SQLCommand
	{
		protected var _table:String;
		
		protected var _sqlConnection:SQLConnection;
		
		protected var _statement:SQLStatement;
		
		protected var changed:Boolean = false;
		
		protected var columns:Object;
		
		protected var filters:Object;
		
		protected var _debugLevel:int = 0;
		
		public function SQLCommand(table:String, sqlConnection:SQLConnection)
		{
			_table = table;
			_sqlConnection = sqlConnection;
			_statement = new SQLStatement();
			_statement.sqlConnection = sqlConnection;
		}
		
		public function get table():String
		{
			return _table;
		}
		
		public function addColumn(column:String, param:String):void
		{
			if (!columns)
			{
				columns = new Object();
			}
			columns[column] = ":" + param;
			changed = true;
		}
		
		public function addFilter(column:String, param:String):void
		{
			if (!filters)
			{
				filters = new Object();
			}
			filters[column] = ":" + param;
			changed = true;
		}
		
		protected function prepareStatement():void { }
		
		public function set debugLevel(value:int):void
		{
			_debugLevel = value;
		}
		
		public function get debugLevel():int
		{
			return _debugLevel;
		}
		
		public function execute():void
		{
			if (changed) prepareStatement();
			if (debugLevel > 0) debug();
			_statement.execute();
		}
		
		protected function debug():void
		{
			trace(this);
		}

	}
}