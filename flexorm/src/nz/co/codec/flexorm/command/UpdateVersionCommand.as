package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;

    public class UpdateVersionCommand extends SQLParameterisedCommand
    {
        public function UpdateVersionCommand(
            sqlConnection:SQLConnection,
            schema:String,
            table:String,
            debugLevel:int=0)
        {
            super(sqlConnection, schema, table, debugLevel);
        }

        override protected function prepareStatement():void
        {
            var sql:String = "update " + _schema + "." + _table + " set version=:version";
            if (_filters)
            {
                sql += " where ";
                for (var filter:String in _filters)
                {
                    sql += filter + "=" + _filters[filter] + " and ";
                }
                sql = sql.substring(0, sql.length - 5); // remove last ' and '
            }
            _statement.text = sql;
            _changed = false;
        }

        public function toString():String
        {
            return "UPDATE VERSION " + _table + ": " + _statement.text;
        }

    }
}