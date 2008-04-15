package nz.co.codec.flexorm.command
{
	import flash.data.SQLConnection;
	import flash.data.SQLStatement;
	
	public class InsertCommand extends SQLParameterisedCommand
	{
		private var _lastInsertRowID:int;
		
		public function InsertCommand(table:String, sqlConnection:SQLConnection)
		{
			super(table, sqlConnection);
			changed = true;
		}
		
		override protected function prepareStatement():void
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
		
		override public function execute():void
		{
			super.execute();
			_lastInsertRowID = _sqlConnection.lastInsertRowID;
			
			// the foreign key constraint triggers appear to be screwing with this
			//_lastInsertRowID = _statement.getResult().lastInsertRowID;
		}
		
		public function get lastInsertRowID():int
		{
			return _lastInsertRowID;
		}
		
		public function toString():String
		{
			return "INSERT " + _table + ": " + _statement.text;
		}

	}
}