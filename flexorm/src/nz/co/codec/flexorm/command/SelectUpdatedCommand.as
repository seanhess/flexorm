package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;

    public class SelectUpdatedCommand extends SQLParameterisedCommand
    {
        private var _result:Array;

        public function SelectUpdatedCommand(
            sqlConnection:SQLConnection,
            schema:String,
            table:String,
            debugLevel:int=0)
        {
            super(sqlConnection, schema, table, debugLevel);
            _statement.text = "select * from " + schema + "." + table +
                " t where t.updated_at > :lastSyncDate";
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
            return "SELECT UPDATED " + _table + ": " + _statement.text;
        }

    }
}