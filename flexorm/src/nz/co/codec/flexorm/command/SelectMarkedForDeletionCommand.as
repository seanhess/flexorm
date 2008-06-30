package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;

    public class SelectMarkedForDeletionCommand extends SQLCommand
    {
        private var _result:Array;

        public function SelectMarkedForDeletionCommand(table:String, sqlConnection:SQLConnection, debugLevel:int=0)
        {
            super(table, sqlConnection, debugLevel);
            _statement.text = "select * from main." + _table +
                " t where t.marked_for_deletion = true";
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
            return "SELECT marked for deletion " + _table + ": " + _statement.text;
        }

    }
}