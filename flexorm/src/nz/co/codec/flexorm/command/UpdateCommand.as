package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;

    import mx.utils.ObjectUtil;
    import mx.utils.StringUtil;

    import nz.co.codec.flexorm.criteria.IFilter;

    public class UpdateCommand extends SQLParameterisedCommand
    {
        private var _syncSupport:Boolean;

        public function UpdateCommand(
            sqlConnection:SQLConnection,
            schema:String,
            table:String,
            syncSupport:Boolean=false,
            debugLevel:int=0)
        {
            super(sqlConnection, schema, table, debugLevel);
            _syncSupport = syncSupport;
        }

        public function clone():UpdateCommand
        {
            var copy:UpdateCommand = new UpdateCommand(_sqlConnection, _schema, _table, _syncSupport, _debugLevel);
            copy.columns = ObjectUtil.copy(_columns);
            copy._filters = _filters.concat();
            return copy;
        }

        override protected function prepareStatement():void
        {
            var sql:String = StringUtil.substitute("update {0}.{1} set ", _schema, _table);
            for (var column:String in _columns)
            {
                sql += StringUtil.substitute("{0}={1},", column, _columns[column]);
            }
            if (_syncSupport && !_columns.hasOwnProperty("version"))
            {
                sql += "version=version+1";
            }
            else
            {
                sql = sql.substring(0, sql.length - 1);
            }
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
            return "UPDATE " + _table + ": " + _statement.text;
        }

    }
}