package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;

    public class SelectMarkedForDeletionCommand extends SQLCommand
    {
        private var _result:Array;

        public function SelectMarkedForDeletionCommand(
            sqlConnection:SQLConnection,
            schema:String,
            table:String,
            debugLevel:int=0)
        {
            super(sqlConnection, schema, table, debugLevel);
        }

        override protected function prepareStatement():void
        {
            var sql:String = "select ";
            for (var column:String in _columns)
            {
                sql += "t." + column + ",";
            }
            sql = sql.substring(0, sql.length - 1); // remove last comma
            sql += " from " + _schema + "." + _table + " t where t.marked_for_deletion=true";
            _statement.text = sql;
            _changed = false;
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
            return "SELECT MARKED FOR DELETION " + _table + ": " + _statement.text;
        }

    }
}