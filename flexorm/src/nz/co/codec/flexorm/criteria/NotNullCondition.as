package nz.co.codec.flexorm.criteria
{
    public class NotNullCondition extends Condition
    {
        public function NotNullCondition(column:String)
        {
            super(column);
        }

        override public function toString():String
        {
            return "t." + column + " is not null";
        }

    }
}