package nz.co.codec.flexorm.criteria
{
    public class EqualsCondition extends ParameterisedCondition
    {
        public function EqualsCondition(table:String, column:String, param:String)
        {
            super(table, column, param);
        }

        override public function toString():String
        {
            return column + "=:" + param;
        }

    }
}