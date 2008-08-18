package nz.co.codec.flexorm.criteria
{
    public class Sort extends Condition
    {
        public static const ASC :String = "asc";

        public static const DESC:String = "desc";

        private var _order:String;

        public function Sort(column:String, order:String=null)
        {
            super(column);
            switch (order)
            {
                case DESC:
                    _order = DESC;
                    break;

                default:
                    _order = ASC;
            }
        }

        override public function toString():String
        {
            return column + " " + _order;
        }

    }
}