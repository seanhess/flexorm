package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;

    public class SQLParameterisedCommand extends SQLCommand
    {
        public function SQLParameterisedCommand(
            sqlConnection:SQLConnection,
            schema:String,
            table:String,
            debugLevel:int=0)
        {
            super(sqlConnection, schema, table, debugLevel);
        }

        public function setParam(param:String, value:Object):void
        {
            if (param == null)
                throw new Error("Null param set on SQLParameterisedCommand. ");

            _statement.parameters[":" + param] = value;
        }

        override protected function debug():void
        {
            super.debug();
            traceParameters();
        }

        protected function traceParameters():void
        {
            for (var key:String in _statement.parameters)
            {
                trace("_param " + key + "=" + _statement.parameters[key]);
            }
        }

    }
}