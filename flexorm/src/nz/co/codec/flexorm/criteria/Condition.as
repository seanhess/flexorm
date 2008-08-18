package nz.co.codec.flexorm.criteria
{
    public class Condition implements Restriction
    {
        private var _column:String;

        public function Condition(column:String)
        {
            _column = column;
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