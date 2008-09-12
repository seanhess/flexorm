package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;

    import mx.utils.StringUtil;

    import nz.co.codec.flexorm.criteria.IFilter;

    public class DeleteCommand extends SQLParameterisedCommand
    {
        public function DeleteCommand(
            sqlConnection:SQLConnection,
            schema:String,
            table:String,
            debugLevel:int=0)
        {
            super(sqlConnection, schema, table, debugLevel);
        }

        override protected function prepareStatement():void
        {
            var sql:String = StringUtil.substitute("delete from {0}.{1}", _schema, _table);
            if (_filters)
            {
                sql += " where ";
                for each(var filter:IFilter in _filters)
                {
                    sql += StringUtil.substitute("{0} and ", filter);
                }
                sql = sql.substring(0, sql.length - 5); // remove last ' and '
            }
            _statement.text = sql;
            _changed = false;
        }

        public function toString():String
        {
            return "DELETE " + _table + ": " + _statement.text;
        }

    }
}