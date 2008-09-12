package nz.co.codec.flexorm.criteria
{
    public class NullCondition extends Condition
    {
        public function NullCondition(table:String, column:String)
        {
            super(table, column);
        }

        override public function toString():String
        {
            return column + " is null";
        }

    }
}