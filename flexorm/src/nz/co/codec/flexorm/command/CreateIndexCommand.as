package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;

    import mx.utils.StringUtil;

    public class CreateIndexCommand extends SQLCommand
    {
        private var _name:String;

        private var indexColumns:Array;

        public function CreateIndexCommand(
            sqlConnection:SQLConnection,
            schema:String,
            table:String,
            name:String,
            debugLevel:int=0)
        {
            super(sqlConnection, schema, table, debugLevel);
            _name = name;
            indexColumns = [];
        }

        public function addIndex(column:String):void
        {
            indexColumns.push(column);
            _changed = true;
        }

        override protected function prepareStatement():void
        {
            var sql:String = StringUtil.substitute("create index if not exists {0}.{1}_{2}_idx on {3}(",
                    _schema, _name? _name : _table, indexColumns[0], _table);
            for each(var column:String in indexColumns)
            {
                sql += StringUtil.substitute("{0} asc,", column);
            }
            sql = sql.substr(0, sql.length - 1) + ")"; // remove last comma
            _statement.text = sql;
            _changed = false;
        }

        public function toString():String
        {
            return "INDEX: " + _statement.text;
        }

    }
}