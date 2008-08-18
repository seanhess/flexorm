package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;

    public class SelectKeysCommand extends SQLCommand
    {
        private var _keys:Array;

        private var _result:Array;

        public function SelectKeysCommand(
            sqlConnection:SQLConnection,
            schema:String,
            table:String,
            debugLevel:int=0)
        {
            super(sqlConnection, schema, table, debugLevel);
            _keys = [];
        }

        public function addKey(value:String):void
        {
            _keys.push(value);
        }

        override protected function prepareStatement():void
        {
            var sql:String = "select ";
            for each(var key:String in _keys)
            {
                sql += "t." + key + ",";
            }
            sql += "t.version from " + _schema + "." + _table + " t";
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
            return "SELECT KEYS " + _table + ": " + _statement.text;
        }

    }
}