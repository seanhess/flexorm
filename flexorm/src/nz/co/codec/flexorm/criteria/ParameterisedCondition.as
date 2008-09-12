package nz.co.codec.flexorm.criteria
{
    public class ParameterisedCondition extends Condition
    {
        private var _param:String;

        public function ParameterisedCondition(table:String, column:String, param:String)
        {
            super(table, column);
            _param = param;
        }

        public function get param():String
        {
            return _param;
        }

        // abstract
        override public function toString():String
        {
            return null;
        }

    }
}