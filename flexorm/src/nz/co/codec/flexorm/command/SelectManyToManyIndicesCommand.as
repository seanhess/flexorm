package nz.co.codec.flexorm.command
{
	import flash.data.SQLConnection;
	import flash.data.SQLStatement;
	
	public class SelectManyToManyIndicesCommand extends SQLParameterisedCommand
	{
		private var _fkColumn:String;
		
		private var _result:Array;
		
		public function SelectManyToManyIndicesCommand(table:String, fkColumn:String, sqlConnection:SQLConnection)
		{
			super(table, sqlConnection);
			_fkColumn = fkColumn;
			changed = true;
		}
		
		override protected function prepareStatement():void
		{
			var selectSQL:String = "select " + _fkColumn + " from " + _table;
			if (filters)
			{
				selectSQL += " where ";
				for (var column:String in filters)
				{
					selectSQL += column + "=" + filters[column] + " and ";
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
			return "SELECT many-to-many indices from " + _table + ": " + _statement.text;
		}

	}
}