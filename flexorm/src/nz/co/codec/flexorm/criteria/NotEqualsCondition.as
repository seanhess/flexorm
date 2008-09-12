package nz.co.codec.flexorm.criteria
{
    public class NotEqualsCondition extends ParameterisedCondition
    {
        public function NotEqualsCondition(table:String, column:String, param:String)
        {
            super(table, column, param);
        }

        override public function toString():String
        {
            return column + "<>:" + param;
        }

    }
}