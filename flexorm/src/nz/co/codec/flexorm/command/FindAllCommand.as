package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;
    import flash.events.SQLEvent;

    import mx.utils.ObjectUtil;

    public class FindAllCommand extends SQLCommand
    {
        private var _result:Array;

        public function FindAllCommand(
            sqlConnection:SQLConnection,
            schema:String,
            table:String,
            debugLevel:int=0)
        {
            super(sqlConnection, schema, table, debugLevel);
        }

        public function clone():FindAllCommand
        {
            var copy:FindAllCommand = new FindAllCommand(_sqlConnection, _schema, _table, _debugLevel);
            copy.columns = ObjectUtil.copy(_columns);
            copy.filters = ObjectUtil.copy(_filters);
            return copy;
        }

        override protected function respond(event:SQLEvent):void
        {
            _result = _statement.getResult().data;
            _responder.result(_result);
        }

        override protected function prepareStatement():void
        {
            var sql:String = "select ";
            for (var column:String in _columns)
            {
                sql += "t." + column + ",";
            }
            sql = sql.substring(0, sql.length - 1); // remove last comma
            sql += " from " + _schema + "." + _table + " t where t.marked_for_deletion<>true";
            _statement.text = sql;
            _changed = false;
        }

        override public function execute():void
        {
            super.execute();
            if (_responder == null)
                _result = _statement.getResult().data;
        }

        public function get result():Array
        {
            return _result;
        }

        public function toString():String
        {
            return "FIND ALL " + _table + ": " + _statement.text;
        }

    }
}