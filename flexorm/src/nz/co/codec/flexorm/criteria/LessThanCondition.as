package nz.co.codec.flexorm.criteria
{
    public class LessThanCondition extends ParameterisedCondition
    {
        public function LessThanCondition(table:String, column:String, param:String)
        {
            super(table, column, param);
        }

        override public function toString():String
        {
            return column + "<:" + param;
        }

    }
}