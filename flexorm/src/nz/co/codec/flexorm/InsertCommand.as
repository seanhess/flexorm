package nz.co.codec.flexorm
{
	import flash.data.SQLConnection;
	import flash.data.SQLStatement;
	
	public class InsertCommand
	{
		private var _table:String;
		
		private var _statement:SQLStatement;
		
		private var _lastInsertRowID:int;
		
		private var columns:Object;
		
		private var changed:Boolean;
		
		public function InsertCommand(table:String, sqlConnection:SQLConnection)
		{
			_table = table;
			_statement = new SQLStatement();
			_statement.sqlConnection = sqlConnection;
			columns = new Object();
			changed = true;
		}
		
		public function addColumn(column:String, param:String):void
		{
			columns[column] = ":" + param;
			changed = true;
		}
		
		private function prepareStatement():void
		{
			var insertSQL:String = "insert into " + _table + "(";
			var values:String = ") values (";
			for (var column:String in columns)
			{
				insertSQL += column + ",";
				values += columns[column] + ",";
			}
			insertSQL = insertSQL.substring(0, insertSQL.length - 1) +
				values.substring(0, values.length - 1) + ")";
			_statement.text = insertSQL;
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
			_lastInsertRowID = _statement.getResult().lastInsertRowID;
		}
		
		public function get lastInsertRowID():int
		{
			return _lastInsertRowID;
		}
		
		public function get table():String
		{
			return _table;
		}
		
		public function toString():String
		{
			return "INSERT " + _table + ": " + _statement.text;
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