package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;

    public class MarkForDeletionCommand extends SQLParameterisedCommand
    {
        public function MarkForDeletionCommand(
            sqlConnection:SQLConnection,
            schema:String,
            table:String,
            debugLevel:int=0)
        {
            super(sqlConnection, schema, table, debugLevel);
        }

        public function clone():MarkForDeletionCommand
        {
            var copy:MarkForDeletionCommand = new MarkForDeletionCommand(_sqlConnection, _schema, _table, _debugLevel);
            copy.filters = _filters;
            return copy;
        }

        override protected function prepareStatement():void
        {
            var sql:String = "update " + _schema + "." + _table + " set marked_for_deletion=true";
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
            return "MARK FOR DELETION " + _table + ": " + _statement.text;
        }

    }
}