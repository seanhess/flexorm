package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;

    public class MarkForDeletionCommand extends SQLParameterisedCommand
    {
        public function MarkForDeletionCommand(table:String, sqlConnection:SQLConnection, debugLevel:int=0)
        {
            super(table, sqlConnection, debugLevel);
        }

        public function clone():MarkForDeletionCommand
        {
            var copy:MarkForDeletionCommand = new MarkForDeletionCommand(_table, _sqlConnection);
            copy.filters = _filters;
            copy.debugLevel = _debugLevel;
            return copy;
        }

        override protected function prepareStatement():void
        {
            var sql:String = "update " + _table +
                " set marked_for_deletion=true";
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
            return "MARK FOR DELETION " + _table + ": " + _statement.text;
        }

    }
}