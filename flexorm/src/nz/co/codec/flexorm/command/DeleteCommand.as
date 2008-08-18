package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;

    public class DeleteCommand extends SQLParameterisedCommand
    {
        public function DeleteCommand(
            sqlConnection:SQLConnection,
            schema:String,
            table:String,
            debugLevel:int=0)
        {
            super(sqlConnection, schema, table, debugLevel);
        }

        override protected function prepareStatement():void
        {
            var sql:String = "delete from " + _schema + "." + _table;
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
            return "DELETE " + _table + ": " + _statement.text;
        }

    }
}