package nz.co.codec.flexorm.criteria
{
    public class NotNullCondition extends Condition
    {
        public function NotNullCondition(table:String, column:String)
        {
            super(table, column);
        }

        override public function toString():String
        {
            return column + " is not null";
        }

    }
}