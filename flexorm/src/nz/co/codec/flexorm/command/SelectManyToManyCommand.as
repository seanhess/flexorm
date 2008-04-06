package nz.co.codec.flexorm.command
{
	import flash.data.SQLConnection;
	import flash.data.SQLStatement;
	
	public class SelectManyToManyCommand extends SQLParameterisedCommand
	{
		private var _associationTable:String;
		
		private var _fkColumn:String;
		
		private var _idColumn:String;
		
		private var _result:Array;
		
		public function SelectManyToManyCommand(
			table:String,
			associationTable:String,
			fkColumn:String,
			idColumn:String,
			sqlConnection:SQLConnection)
		{
			super(table, sqlConnection);
			_associationTable = associationTable;
			_fkColumn = fkColumn;
			_idColumn = idColumn;
			changed = true;
		}
		
		override protected function prepareStatement():void
		{
			var selectSQL:String = "select * from " + _table +
				" a inner join " + _associationTable + " b" +
				" on b." + _fkColumn + "=a." + _idColumn;
			if (filters)
			{
				selectSQL += " where ";
				for (var column:String in filters)
				{
					selectSQL += "b." + column + "=" + filters[column] + " and ";
				}
				// remove last ' and '
				selectSQL = selectSQL.substring(0, selectSQL.length - 5);
			}
			_statement.text = selectSQL;
			changed = false;
		}
		
		override public function execute():void
		{
			super.execute();
			_result = _statement.getResult().data;
		}
		
		public function get result():Array
		{
			return _result;
		}
		
		public function toString():String
		{
			return "SELECT many-to-many " + _table + ": " + _statement.text;
		}

	}
}