package nz.co.codec.flexorm
{
	import flash.data.SQLConnection;
	import flash.data.SQLStatement;
	
	public class DeleteManyToManyCommand
	{
		private var _table:String;
		
		private var _statement:SQLStatement;
		
		private var whereClause:String;
		
		private var andClause:String;
		
		private var changed:Boolean;
		
		public function DeleteManyToManyCommand(table:String, sqlConnection:SQLConnection)
		{
			_table = table;
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
		
		public function setFkColumn(column:String, param:String):void
		{
			andClause = " and " + column + "=:" + param;
			changed = true;
		}
		
		private function prepareStatement():void
		{
			var deleteSQL:String = "delete from " + _table + whereClause + andClause;
			_statement.text = deleteSQL;
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
		}
		
		public function get table():String
		{
			return _table;
		}
		
		public function toString():String
		{
			return "DELETE many-to-many " + _table + ": " + _statement.text;
		}

	}
}