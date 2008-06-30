package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;
    import flash.events.SQLEvent;

    public class SelectCommand extends SQLParameterisedCommand
    {
        private var _indexColumn:String;

        private var _result:Array;

        public function SelectCommand(
            table:String,
            sqlConnection:SQLConnection,
            debugLevel:int=0,
            indexColumn:String=null)
        {
            super(table, sqlConnection, debugLevel);
            _indexColumn = indexColumn;
        }

        public function clone():SelectCommand
        {
            var copy:SelectCommand = new SelectCommand(_table, _sqlConnection, _debugLevel, _indexColumn);
            copy.columns = _columns;
            copy.filters = _filters;
            return copy;
        }

        override protected function prepareStatement():void
        {
            var sql:String = "select * from " + _table;
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
            if (_indexColumn)
            {
                sql += " order by " + _indexColumn;
            }
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
            {
                _result = _statement.getResult().data;
            }
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