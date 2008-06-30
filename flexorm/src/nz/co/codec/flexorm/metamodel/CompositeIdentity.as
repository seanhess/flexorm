package nz.co.codec.flexorm.metamodel
{
    public class CompositeIdentity implements IIdentity
    {
        /**
         * The associated entity of the many-to-one association.
         */
        public var associatedEntity:Entity;

        private var _property:String;

        /**
         * Property name of the many-to-one association.
         */
        public function set property(value:String):void
        {
            _property = value;
        }

        public function get property():String
        {
            return _property;
        }

        public function CompositeIdentity(hash:Object=null)
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