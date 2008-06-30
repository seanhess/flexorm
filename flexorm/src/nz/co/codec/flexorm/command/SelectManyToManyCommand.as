package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;
    import flash.events.SQLEvent;

    public class SelectManyToManyCommand extends SQLParameterisedCommand
    {
        private var _associationTable:String;

        private var _joins:Object;

        private var _indexColumn:String;

        private var _result:Array;

        public function SelectManyToManyCommand(
            table:String,
            associationTable:String,
            sqlConnection:SQLConnection,
            debugLevel:int=0,
            indexColumn:String=null)
        {
            super(table, sqlConnection, debugLevel);
            _associationTable = associationTable;
            _indexColumn = indexColumn;
        }

        public function clone():SelectManyToManyCommand
        {
            var copy:SelectManyToManyCommand = new SelectManyToManyCommand(_table, _associationTable, _sqlConnection, _debugLevel, _indexColumn);
            copy.columns = _columns;
            copy.filters = _filters;
            copy.joins = _joins;
            return copy;
        }

        protected function set joins(value:Object):void
        {
            _joins = value;
        }

        public function addJoin(fkColumn:String, idColumn:String):void
        {
            if (_joins == null)
                _joins = new Object();

            _joins[fkColumn] = idColumn;
            _changed = true;
        }

        override protected function prepareStatement():void
        {
            var sql:String = "select * from " + _table +
                " a inner join " + _associationTable + " b on ";

            if (_joins == null)
                throw new Error("Join columns on SelectManyToManyCommand not set");

            for (var fkColumn:String in _joins)
            {
                sql += "b." + fkColumn + "=a." + _joins[fkColumn] + " and ";
            }
            // remove last ' and '
            sql = sql.substring(0, sql.length - 5);

            if (_filters)
            {
                sql += " where ";
                for (var filter:String in _filters)
                {
                    sql += "b." + filter + "=" + _filters[filter] + " and ";
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
            return "SELECT many-to-many " + _table + ": " + _statement.text;
        }

    }
}