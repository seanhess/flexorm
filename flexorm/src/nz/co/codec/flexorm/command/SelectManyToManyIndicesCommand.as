package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;
    import flash.events.SQLEvent;

    public class SelectManyToManyIndicesCommand extends SQLParameterisedCommand
    {
        private var _result:Array;

        public function SelectManyToManyIndicesCommand(table:String, sqlConnection:SQLConnection, debugLevel:int=0)
        {
            super(table, sqlConnection, debugLevel);
        }

        override protected function prepareStatement():void
        {
            var sql:String = "select ";
            for (var column:String in _columns)
            {
                sql += "t." + column + ",";
            }
            // remove last comma
            sql = sql.substring(0, sql.length - 1);
            sql += " from " + _table + " t";
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
            return "SELECT many-to-many indices from " + _table + ": " + _statement.text;
        }

    }
}