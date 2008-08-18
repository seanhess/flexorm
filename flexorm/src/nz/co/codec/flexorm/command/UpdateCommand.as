package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;

    import mx.utils.ObjectUtil;

    public class UpdateCommand extends SQLParameterisedCommand
    {
        public function UpdateCommand(
            sqlConnection:SQLConnection,
            schema:String,
            table:String,
            debugLevel:int=0)
        {
            super(sqlConnection, schema, table, debugLevel);
        }

        public function clone():UpdateCommand
        {
            var copy:UpdateCommand = new UpdateCommand(_sqlConnection, _schema, _table, _debugLevel);
            copy.columns = ObjectUtil.copy(_columns);
            copy.filters = ObjectUtil.copy(_filters);
            return copy;
        }

        override protected function prepareStatement():void
        {
            var sql:String = "update " + _schema + "." + _table + " set ";
            for (var column:String in _columns)
            {
                sql += column + "=" + _columns[column] + ",";
            }
            sql = sql.substring(0, sql.length - 1);
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
            return "UPDATE " + _table + ": " + _statement.text;
        }

    }
}