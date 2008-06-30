package nz.co.codec.flexorm.metamodel
{
    public class PrimaryIdentity implements IIdentity
    {
        /**
         * Database column name
         */
        public var column:String;

        private var _property:String;

        /**
         * Property name
         */
        public function set property(value:String):void
        {
            _property = value;
        }

        public function get property():String
        {
            return _property;
        }

        public function PrimaryIdentity(hash:Object=null)
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