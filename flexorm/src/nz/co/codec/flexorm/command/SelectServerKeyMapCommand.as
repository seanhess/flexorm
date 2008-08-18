package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;

    public class SelectServerKeyMapCommand extends SQLCommand
    {
        private var _result:Array;

        public function SelectServerKeyMapCommand(
            sqlConnection:SQLConnection,
            schema:String,
            table:String,
            localKey:String,
            debugLevel:int=0)
        {
            super(sqlConnection, schema, table, debugLevel);
            _statement.text = "select t." + localKey +
                ",t.server_id,t.version from " + schema + "." + table + " t";
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
            return "SELECT SERVER KEY MAP " + _table + ": " + _statement.text;
        }

    }
}