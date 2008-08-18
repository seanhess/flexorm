package nz.co.codec.flexorm.metamodel
{
    public class PrimaryKey implements Key
    {
        /**
         * Database column name
         */
        public var column:String;

        /**
         * Property name
         */
        private var _property:String;

        public function set property(value:String):void
        {
            _property = value;
        }

        public function get property():String
        {
            return _property;
        }

        public function PrimaryKey(hash:Object=null)
        {
            for (var key:String in hash)
            {
                if (hasOwnProperty(key))
                {
                    this[key] = hash[key];
                }
            }
        }

    }
}