package nz.co.codec.flexorm
{
	import flash.data.SQLConnection;
	import flash.data.SQLStatement;
	
	public class CreateCommand
	{
		private var _table:String;
		
		private var _statement:SQLStatement;
		
		private var columns:Object;
		
		private var changed:Boolean;
		
		public function CreateCommand(table:String, sqlConnection:SQLConnection)
		{
			_table = table;
			_statement = new SQLStatement();
			_statement.sqlConnection = sqlConnection;
			columns = new Object();
			changed = true;
		}
		
		public function setIdColumn(column:String):void
		{
			columns[column] = "integer primary key autoincrement";
			changed = true;
		}
		
		public function addColumn(column:String, type:String):void
		{
			columns[column] = type;
			changed = true;
		}
		
		private function prepareStatement():void
		{
			var createSQL:String = "create table if not exists " + _table + " (";
			for (var column:String in columns)
			{
				createSQL += column + " " + columns[column] + ",";
			}
			createSQL = createSQL.substring(0, createSQL.length - 1) + ")"; // remove last comma
			_statement.text = createSQL;
			changed = false;
		}
		
		public function execute():void
		{
			if (changed) prepareStatement();
			//trace(this);
			_statement.execute();
		}
		
		public function get table():String
		{
			return _table;
		}
		
		public function toString():String
		{
			return "CREATE " + _table + ": " + _statement.text;
		}

	}
}