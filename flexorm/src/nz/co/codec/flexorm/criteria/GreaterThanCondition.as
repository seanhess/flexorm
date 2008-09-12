package nz.co.codec.flexorm.criteria
{
    public class GreaterThanCondition extends ParameterisedCondition
    {
        public function GreaterThanCondition(table:String, column:String, param:String)
        {
            super(table, column, param);
        }

        override public function toString():String
        {
            return column + ">:" + param;
        }

    }
}