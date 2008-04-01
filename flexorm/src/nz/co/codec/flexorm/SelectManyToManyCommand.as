package nz.co.codec.flexorm
{
	import flash.data.SQLConnection;
	import flash.data.SQLStatement;
	
	public class SelectManyToManyCommand
	{
		private var _table:String;
		
		private var _associationTable:String;
		
		private var _fkColumn:String;
		
		private var _idColumn:String;
		
		private var _statement:SQLStatement;
		
		private var _result:Array;
		
		private var whereClause:String;
		
		private var changed:Boolean;
		
		public function SelectManyToManyCommand(
			table:String,
			associationTable:String,
			fkColumn:String,
			idColumn:String,
			sqlConnection:SQLConnection)
		{
			_table = table;
			_associationTable = associationTable;
			_fkColumn = fkColumn;
			_idColumn = idColumn;
			_statement = new SQLStatement();
			_statement.sqlConnection = sqlConnection;
			whereClause = "";
			changed = true;
		}
		
		public function setIdColumn(column:String, param:String):void
		{
			whereClause = " where b." + column + "=:" + param;
			changed = true;
		}
		
		private function prepareStatement():void
		{
			var selectSQL:String = "select * from " + _table +
				" a inner join " + _associationTable + " b" +
				" on b." + _fkColumn + "=a." + _idColumn +
				whereClause;
			_statement.text = selectSQL;
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
			_statement.execute();
			_result = _statement.getResult().data;
		}
		
		public function get result():Array
		{
			return _result;
		}
		
		public function get table():String
		{
			return _table;
		}
		
		public function toString():String
		{
			return "SELECT many-to-many " + _table + ": " + _statement.text;
		}

	}
}