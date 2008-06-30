package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;

    public class SelectIdMapCommand extends SQLCommand
    {
        private var _result:Array;

        public function SelectIdMapCommand(
            table:String,
            idColumn:String,
            sqlConnection:SQLConnection,
            debugLevel:int=0)
        {
            super(table, sqlConnection, debugLevel);
            _statement.text = "select t." + idColumn +
                ",t.server_id from main." + table +
                " t where t.server_id > 0";
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
            return "SELECT ID Map from " + _table + ": " + _statement.text;
        }

    }
}