package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;

    public class CreateIndexCommand extends SQLCommand
    {
        private var _name:String;

        private var indexColumns:Array = [];

        public function CreateIndexCommand(table:String, name:String, sqlConnection:SQLConnection, debugLevel:int=0)
        {
            super(table, sqlConnection, debugLevel);
            _name = name;
        }

        public function addIndexColumn(column:String):void
        {
            indexColumns.push(column);
            _changed = true;
        }

        override protected function prepareStatement():void
        {
            var sql:String = "create index if not exists main.";
            sql += (_name)? _name : _table + "_" + indexColumns[0] + "_idx";
            sql += " on " + _table + "(";
            for each(var column:String in indexColumns)
            {
                sql += column + " asc,";
            }
            sql = sql.substr(0, sql.length - 1); // remove last comma
            sql += ")";
            _statement.text = sql;
            _changed = false;
        }

        public function toString():String
        {
            return "CREATE INDEX: " + _statement.text;
        }

    }
}