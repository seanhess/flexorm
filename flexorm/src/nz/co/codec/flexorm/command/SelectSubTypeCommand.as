package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;
    import flash.events.SQLEvent;

    import mx.utils.ObjectUtil;

    public class SelectSubTypeCommand extends SQLParameterisedCommand
    {
        private var _parentTable:String;

        private var _joins:Object;

        private var _indexColumn:String;

        private var _result:Array;

        public function SelectSubTypeCommand(
            sqlConnection:SQLConnection,
            schema:String,
            table:String,
            debugLevel:int=0)
        {
            super(sqlConnection, schema, table, debugLevel);
            _joins = {};
        }

        public function clone():SelectSubTypeCommand
        {
            var copy:SelectSubTypeCommand = new SelectSubTypeCommand(_sqlConnection, _schema, _table, _debugLevel);
            copy.columns = ObjectUtil.copy(_columns);
            copy.filters = ObjectUtil.copy(_filters);
            copy.parentTable = _parentTable;
            copy.joins = ObjectUtil.copy(_joins);
            copy.indexColumn = _indexColumn;
            return copy;
        }

        public function set parentTable(value:String):void
        {
            _parentTable = value;
        }

        protected function set joins(value:Object):void
        {
            _joins = value;
        }

        public function addJoin(fk:String, pk:String):void
        {
            _joins[fk] = pk;
            _changed = true;
        }

        public function set indexColumn(value:String):void
        {
            _indexColumn = value;
        }

        override protected function prepareStatement():void
        {
            if (_joins == null)
                throw new Error("Join columns on SelectSubTypeCommand not set. ");

            var sql:String = "select ";
            for (var column:String in _columns)
            {
                sql += "t." + column + ",";
            }
            sql = sql.substring(0, sql.length - 1); // remove last comma
            sql+= " from " + _schema + "." + _table + " t inner join " +
                _parentTable + " p on ";

            for (var fk:String in _joins)
            {
                sql += "p." + fk + "=t." + _joins[fk] + " and ";
            }
            sql = sql.substring(0, sql.length - 5); // remove last ' and '

            if (_filters)
            {
                sql += " where ";
                for (var filter:String in _filters)
                {
                    sql += "p." + filter + "=" + _filters[filter] + " and ";
                }
                sql = sql.substring(0, sql.length - 5); // remove last ' and '
            }
            if (_indexColumn)
                sql += " order by " + _indexColumn;

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
            return "SELECT SUBTYPE " + _table + ": " + _statement.text;
        }

    }
}