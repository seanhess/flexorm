package nz.co.codec.flexorm.criteria
{
    public class LikeCondition extends Condition
    {
        private var _str:String;

        public function LikeCondition(column:String, str:String)
        {
            super(column);
            _str = str;
        }

        override public function toString():String
        {
            return "t." + column + " like '%" + _str + "%'";
        }

    }
}