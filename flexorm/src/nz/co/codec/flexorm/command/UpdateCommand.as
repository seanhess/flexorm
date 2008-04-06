package nz.co.codec.flexorm.command
{
	import flash.data.SQLConnection;
	import flash.data.SQLStatement;
	
	public class UpdateCommand extends SQLParameterisedCommand
	{
		public function UpdateCommand(table:String, sqlConnection:SQLConnection)
		{
			super(table, sqlConnection);
			changed = true;
		}
		
		override protected function prepareStatement():void
		{
			var updateSQL:String = "update " + _table + " set ";
			for (var column:String in columns)
			{
				updateSQL += column + "=" + columns[column] + ",";
			}
			updateSQL = updateSQL.substring(0, updateSQL.length - 1);
			if (filters)
			{
				updateSQL += " where ";
				for (var col:String in filters)
				{
					updateSQL += col + "=" + filters[col] + " and ";
				}
				// remove last ' and '
				updateSQL = updateSQL.substring(0, updateSQL.length - 5);
			}
			_statement.text = updateSQL;
			changed = false;
		}
		
		public function toString():String
		{
			return "UPDATE " + _table + ": " + _statement.text;
		}

	}
}