package nz.co.codec.flexorm.criteria
{
    import mx.utils.StringUtil;

    public class Sort extends Condition
    {
        public static const ASC :String = "asc";

        public static const DESC:String = "desc";

        private var _order:String;

        public function Sort(table:String, column:String, order:String=null)
        {
            super(table, column);
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
            return StringUtil.substitute("{0} {1}", column, _order);
        }

    }
}