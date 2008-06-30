package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;

    public class SelectFkMapCommand extends SQLCommand
    {
        private var _idColumns:Array = [];

        private var _result:Array;

        public function SelectFkMapCommand(table:String, sqlConnection:SQLConnection, debugLevel:int=0)
        {
            super(table, sqlConnection, debugLevel);
        }

        public function addIdColumn(value:String):void
        {
            _idColumns.push(value);
        }

        override protected function prepareStatement():void
        {
            var sql:String = "select ";
            for each(var column:String in _idColumns)
            {
                sql += "t." + column + ",";
            }
            sql = sql.substring(0, sql.length - 1); // remove last comma
            sql += " from " + _table + " t";
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
            return "SELECT FK Map from " + _table + ": " + _statement.text;
        }

    }
}