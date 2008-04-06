package nz.co.codec.flexorm.command
{
	import flash.data.SQLConnection;
	import flash.data.SQLStatement;
	
	public class FindAllCommand extends SQLCommand
	{
		private var _result:Array;
		
		public function FindAllCommand(table:String, sqlConnection:SQLConnection)
		{
			super(table, sqlConnection);
			_statement.text = "select * from " + table;
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
			return "FIND ALL " + _table + ": " + _statement.text;
		}

	}
}