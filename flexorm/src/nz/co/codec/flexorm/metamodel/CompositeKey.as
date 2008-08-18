package nz.co.codec.flexorm.metamodel
{
    public class CompositeKey implements Key
    {
        /**
         * The associated entity of the many-to-one association.
         */
        public var associatedEntity:Entity;

        /**
         * Property name of the many-to-one association.
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

        public function CompositeKey(hash:Object=null)
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