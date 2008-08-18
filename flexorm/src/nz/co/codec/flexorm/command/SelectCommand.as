package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;
    import flash.events.SQLEvent;

    import mx.utils.ObjectUtil;

    public class SelectCommand extends SQLParameterisedCommand
    {
        private var _indexColumn:String;

        private var _result:Array;

        public function SelectCommand(
            sqlConnection:SQLConnection,
            schema:String,
            table:String,
            debugLevel:int=0)
        {
            super(sqlConnection, schema, table, debugLevel);
        }

        public function clone():SelectCommand
        {
            var copy:SelectCommand = new SelectCommand(_sqlConnection, _schema, _table, _debugLevel);
            copy.columns = ObjectUtil.copy(_columns);
            copy.filters = ObjectUtil.copy(_filters);
            copy.indexColumn = _indexColumn;
            return copy;
        }

        public function set indexColumn(value:String):void
        {
            _indexColumn = value;
        }

        override protected function prepareStatement():void
        {
            var sql:String = "select ";
            for (var column:String in _columns)
            {
                sql += "t." + column + ",";
            }
            sql = sql.substring(0, sql.length - 1); // remove last comma
            sql += " from " + _schema + "." + _table + " t";
            if (_filters)
            {
                sql += " where ";
                for (var filter:String in _filters)
                {
                    sql += "t." + filter + "=" + _filters[filter] + " and ";
                }
                sql = sql.substring(0, sql.length - 5); // remove last ' and '
            }
            if (_indexColumn)
                sql += " order by t." + _indexColumn;

            _statement.text = sql;
            _changed = false;
        }

        override protected function respond(event:SQLEvent):void
        {
            _result = _statement.getResult().data;
            _responder.result(_result);
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
            return "SELECT " + _table + ": " + _statement.text;
        }

    }
}