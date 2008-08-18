package nz.co.codec.flexorm.criteria
{
    public class NullCondition extends Condition
    {
        public function NullCondition(column:String)
        {
            super(column);
        }

        override public function toString():String
        {
            return "t." + column + " is null";
        }

    }
}