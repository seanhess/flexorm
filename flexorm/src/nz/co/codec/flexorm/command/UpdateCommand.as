package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;

    public class UpdateCommand extends SQLParameterisedCommand
    {
        public function UpdateCommand(table:String, sqlConnection:SQLConnection, debugLevel:int=0)
        {
            super(table, sqlConnection, debugLevel);
        }

        public function clone():UpdateCommand
        {
            var copy:UpdateCommand = new UpdateCommand(_table, _sqlConnection);
            copy.columns = _columns;
            copy.filters = _filters;
            copy.debugLevel = _debugLevel;
            return copy;
        }

        override protected function prepareStatement():void
        {
            var sql:String = "update " + _table + " set ";
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
                // remove last ' and '
                sql = sql.substring(0, sql.length - 5);
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