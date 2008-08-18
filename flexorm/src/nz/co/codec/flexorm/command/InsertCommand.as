package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;
    import flash.events.SQLEvent;

    import mx.utils.ObjectUtil;

    public class InsertCommand extends SQLParameterisedCommand
    {
        private var _lastInsertRowID:int;

        public function InsertCommand(
            sqlConnection:SQLConnection,
            schema:String,
            table:String,
            debugLevel:int=0)
        {
            super(sqlConnection, schema, table, debugLevel);
        }

        public function clone():InsertCommand
        {
            var copy:InsertCommand = new InsertCommand(_sqlConnection, _schema, _table, _debugLevel);
            copy.columns = ObjectUtil.copy(_columns);
            copy.filters = ObjectUtil.copy(_filters);
            return copy;
        }

        override protected function prepareStatement():void
        {
            var sql:String = "insert into " + _schema + "." + _table + "(";
            var values:String = ") values (";
            for (var column:String in _columns)
            {
                sql += column + ",";
                values += _columns[column] + ",";
            }
            sql = sql.substring(0, sql.length-1) + values.substring(0, values.length-1) + ")";
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