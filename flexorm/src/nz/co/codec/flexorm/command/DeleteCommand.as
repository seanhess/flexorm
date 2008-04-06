package nz.co.codec.flexorm.command
{
	import flash.data.SQLConnection;
	
	public class DeleteCommand extends SQLParameterisedCommand
	{
		public function DeleteCommand(table:String, sqlConnection:SQLConnection)
		{
			super(table, sqlConnection);
			changed = true;
		}
		
		override protected function prepareStatement():void
		{
			var deleteSQL:String = "delete from " + _table;
			if (filters)
			{
				deleteSQL += " where ";
				for (var column:String in filters)
				{
					deleteSQL += column + "=" + filters[column] + " and ";
				}
				// remove last ' and '
				deleteSQL = deleteSQL.substring(0, deleteSQL.length - 5);
			}
			_statement.text = deleteSQL;
			changed = false;
		}
		
		public function toString():String
		{
			return "DELETE " + _table + ": " + _statement.text;
		}

	}
}