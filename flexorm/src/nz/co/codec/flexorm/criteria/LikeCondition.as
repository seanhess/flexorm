package nz.co.codec.flexorm.criteria
{
    public class LikeCondition extends Condition
    {
        private var _str:String;

        public function LikeCondition(table:String, column:String, str:String)
        {
            super(table, column);
            _str = str;
        }

        override public function toString():String
        {
            return column + " like '%" + _str + "%'";
        }

    }
}