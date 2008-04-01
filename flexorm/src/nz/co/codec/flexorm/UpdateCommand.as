package nz.co.codec.flexorm
{
	import flash.data.SQLConnection;
	import flash.data.SQLStatement;
	
	public class UpdateCommand
	{
		private var _table:String;
		
		private var _statement:SQLStatement;
		
		private var columns:Object;
		
		private var whereClause:String;
		
		private var changed:Boolean;
		
		public function UpdateCommand(table:String, sqlConnection:SQLConnection)
		{
			_table = table;
			_statement = new SQLStatement();
			_statement.sqlConnection = sqlConnection;
			columns = new Object();
			whereClause = "";
			changed = true;
		}
		
		public function setIdColumn(column:String, param:String):void
		{
			whereClause = " where " + column + "=:" + param;
			changed = true;
		}
		
		public function addColumn(column:String, param:String):void
		{
			columns[column] = ":" + param;
			changed = true;
		}
		
		private function prepareStatement():void
		{
			var updateSQL:String = "update " + _table + " set ";
			for (var column:String in columns)
			{
				updateSQL += column + "=" + columns[column] + ",";
			}
			updateSQL = updateSQL.substring(0, updateSQL.length - 1) + whereClause;
			_statement.text = updateSQL;
			changed = false;
		}
		
		public function setParam(param:String, value:Object):void
		{
			_statement.parameters[":" + param] = value;
		}
		
		public function execute():void
		{
			if (changed) prepareStatement();
			//trace(this);
			//traceParameters();
			_statement.execute();
		}
		
		public function get table():String
		{
			return _table;
		}
		
		public function toString():String
		{
			return "UPDATE " + _table + ": " + _statement.text;
		}
		
		private function traceParameters():void
		{
			for (var key:String in _statement.parameters)
			{
				trace("param " + key + "=" + _statement.parameters[key]);
			}
		}

	}
}