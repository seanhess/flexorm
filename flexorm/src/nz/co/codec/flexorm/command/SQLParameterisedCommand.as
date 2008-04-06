package nz.co.codec.flexorm.command
{
	import flash.data.SQLConnection;

	public class SQLParameterisedCommand extends SQLCommand
	{
		public function SQLParameterisedCommand(table:String, sqlConnection:SQLConnection)
		{
			super(table, sqlConnection);
		}
		
		public function setParam(param:String, value:Object):void
		{
			_statement.parameters[":" + param] = value;
		}
		
		protected function traceParameters():void
		{
			for (var key:String in _statement.parameters)
			{
				trace("_param " + key + "=" + _statement.parameters[key]);
			}
		}
		
		override protected function debug():void
		{
			super.debug();
			traceParameters();
		}

	}
}