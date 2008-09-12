package nz.co.codec.flexorm.criteria
{
    public class SQLCondition implements ICondition
    {
        private var _table:String;

        private var _sql:String;

        public function SQLCondition(table:String, sql:String)
        {
            _table = table;
            _sql = sql;
        }

        public function get table():String
        {
            return _table;
        }

        public function toString():String
        {
            return _sql;
        }

    }
}