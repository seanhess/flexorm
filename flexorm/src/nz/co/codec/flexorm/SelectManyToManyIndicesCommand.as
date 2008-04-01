package nz.co.codec.flexorm
{
	import flash.data.SQLConnection;
	import flash.data.SQLStatement;
	
	public class SelectManyToManyIndicesCommand
	{
		private var _table:String;
		
		private var _fkColumn:String;
		
		private var _statement:SQLStatement;
		
		private var _result:Array;
		
		private var whereClause:String;
		
		private var changed:Boolean;
		
		public function SelectManyToManyIndicesCommand(table:String, fkColumn:String, sqlConnection:SQLConnection)
		{
			_table = table;
			_fkColumn = fkColumn;
			_statement = new SQLStatement();
			_statement.sqlConnection = sqlConnection;
			whereClause = "";
			changed = true;
		}
		
		public function setIdColumn(column:String, param:String):void
		{
			whereClause = " where " + column + "=:" + param;
			changed = true;
		}
		
		private function prepareStatement():void
		{
			var selectSQL:String = "select " + _fkColumn + " from " + _table + whereClause;
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
			return "SELECT many-to-many indices from " + _table + ": " + _statement.text;
		}

	}
}