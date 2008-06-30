package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;
    import flash.events.SQLEvent;

    public class FindAllCommand extends SQLCommand
    {
        private var _result:Array;

        public function FindAllCommand(table:String, sqlConnection:SQLConnection, debugLevel:int=0)
        {
            super(table, sqlConnection, debugLevel);
            _statement.text = "select * from " + table +
                " where marked_for_deletion <> true";
        }

        public function clone():FindAllCommand
        {
            var copy:FindAllCommand = new FindAllCommand(_table, _sqlConnection);
            copy.columns = _columns;
            copy.filters = _filters;
            copy.debugLevel = _debugLevel;
            return copy;
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
            return "FIND ALL " + _table + ": " + _statement.text;
        }

    }
}