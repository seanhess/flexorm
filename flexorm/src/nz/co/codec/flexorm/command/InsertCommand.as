package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;
    import flash.events.SQLEvent;

    public class InsertCommand extends SQLParameterisedCommand
    {
        private var _lastInsertRowID:int;

        public function InsertCommand(table:String, sqlConnection:SQLConnection, debugLevel:int=0)
        {
            super(table, sqlConnection, debugLevel);
        }

        public function clone():InsertCommand
        {
            var copy:InsertCommand = new InsertCommand(_table, _sqlConnection);
            copy.columns = _columns;
            copy.filters = _filters;
            copy.debugLevel = _debugLevel;
            return copy;
        }

        override protected function prepareStatement():void
        {
            var sql:String = "insert into " + _table + "(";
            var values:String = ") values (";
            for (var column:String in _columns)
            {
                sql += column + ",";
                values += _columns[column] + ",";
            }
            sql = sql.substring(0, sql.length - 1) +
                values.substring(0, values.length - 1) + ")";
            _statement.text = sql;
            _changed = false;
        }

        override protected function respond(event:SQLEvent):void
        {
            _lastInsertRowID = _sqlConnection.lastInsertRowID;
            _responder.result(_lastInsertRowID);
        }

        override public function execute():void
        {
            super.execute();
            if (_responder == null)
            {
                _lastInsertRowID = _sqlConnection.lastInsertRowID;

                // the foreign key constraint triggers appear to be screwing with this
                //_lastInsertRowID = _statement.getResult().lastInsertRowID;
            }
        }

        public function get lastInsertRowID():int
        {
            return _lastInsertRowID;
        }

        public function toString():String
        {
            return "INSERT " + _table + ": " + _statement.text;
        }

    }
}