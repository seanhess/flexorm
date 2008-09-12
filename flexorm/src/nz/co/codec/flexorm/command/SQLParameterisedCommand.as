package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;

    import mx.utils.StringUtil;

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
            for (var param:String in _statement.parameters)
            {
                var value:Object = _statement.parameters[param];
                var n:int = 20 - param.length;
                while (n-- > 0)
                    param += " ";
                if (value is String)
                {
                    trace(StringUtil.substitute("_param {0}=\"{1}\"", param, value));
                }
                else
                {
                    trace(StringUtil.substitute("_param {0}={1}", param, value));
                }
            }
            trace();
        }

    }
}