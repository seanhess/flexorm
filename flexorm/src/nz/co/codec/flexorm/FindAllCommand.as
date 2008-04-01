package nz.co.codec.flexorm
{
	import flash.data.SQLConnection;
	import flash.data.SQLStatement;
	
	public class FindAllCommand
	{
		private var _table:String;
		
		private var _statement:SQLStatement;
		
		private var _result:Array;
		
		public function FindAllCommand(table:String, sqlConnection:SQLConnection)
		{
			_table = table;
			_statement = new SQLStatement();
			_statement.sqlConnection = sqlConnection;
			_statement.text = "select * from " + table;
		}
		
		public function execute():void
		{
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
			return "FIND ALL " + _table + ": " + _statement.text;
		}

	}
}