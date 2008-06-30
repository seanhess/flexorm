package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;

    public class SelectUnsynchronisedCommand extends SQLParameterisedCommand
    {
        private var _result:Array;

        public function SelectUnsynchronisedCommand(table:String, sqlConnection:SQLConnection, debugLevel:int=0)
        {
            super(table, sqlConnection, debugLevel);
            _statement.text = "select * from main." + _table +
                " t where t.updated_at > :lastSyncDate";
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
            return "SELECT unsynchronised " + _table + ": " + _statement.text;
        }

    }
}