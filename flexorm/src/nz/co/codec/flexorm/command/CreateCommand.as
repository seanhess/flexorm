package nz.co.codec.flexorm.command
{
	import flash.data.SQLConnection;
	
	public class CreateCommand extends SQLCommand
	{
		private var pk:String;
		
		public function CreateCommand(table:String, sqlConnection:SQLConnection)
		{
			super(table, sqlConnection);
			changed = true;
		}
		
		public function setPk(column:String):void
		{
			pk = column + " integer primary key autoincrement";
			changed = true;
		}
		
		override public function addColumn(column:String, type:String):void
		{
			if (!columns)
			{
				columns = new Object();
			}
			columns[column] = type;
			changed = true;
		}
		
		override protected function prepareStatement():void
		{
			var createSQL:String = "create table if not exists " + _table
				+ " (";
			if (pk) createSQL += pk + ",";
			for (var column:String in columns)
			{
				createSQL += column + " " + columns[column] + ",";
			}
			createSQL = createSQL.substring(0, createSQL.length - 1) + ")"; // remove last comma
			_statement.text = createSQL;
			changed = false;
		}
		
		public function toString():String
		{
			return "CREATE " + _table + ": " + _statement.text;
		}

	}
}