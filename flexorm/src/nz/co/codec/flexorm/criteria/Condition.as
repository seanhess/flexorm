package nz.co.codec.flexorm.criteria
{
    public class Condition implements ICondition
    {
        private var _table:String;

        private var _column:String;

        public function Condition(table:String, column:String)
        {
            _table = table;
            _column = column;
        }

        public function get table():String
        {
            return _table;
        }

        protected function get column():String
        {
            return _column;
        }

        // abstract
        public function toString():String
        {
            return null;
        }

    }
}