package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;
    import flash.events.SQLEvent;

    public class SelectNestedSetTypesCommand extends SQLParameterisedCommand
    {
        private var _result:Array;

        public function SelectNestedSetTypesCommand(sqlConnection:SQLConnection, schema:String, table:String, debugLevel:int=0)
        {
            super(sqlConnection, schema, table, debugLevel);
            _statement.text = "select distinct entity_type from " +
                schema + "." + table +
                " where lft>:lft and rgt<:rgt order by lft";
        }

        override public function execute():void
        {
            super.execute();
            if (_responder == null)
                _result = _statement.getResult().data;
        }

        override protected function respond(event:SQLEvent):void
        {
            _result = _statement.getResult().data;
            _responder.result(_result);
        }

        public function get result():Array
        {
            return _result;
        }

        public function toString():String
        {
            return "SELECT NESTED SET TYPES " + _statement.text;
        }

    }
}