package nz.co.codec.flexorm.metamodel
{
    public class Identity
    {
        public var column:String;

        public var property:String;

        public var fkColumn:String;

        public var fkProperty:String;

        public var path:Array;

        public function getValue(obj:Object):int
        {
            if (obj == null)
                return 0;

            if (path.length == 0)
                return obj[property];

            return getVal(obj, path.concat());
        }

        private function getVal(obj:Object, path:Array):int
        {
            var key:Key = path.shift() as Key;
            if (path.length > 0)
            {
                var value:Object = obj[key.property];
                return getVal(value, path);
            }
            else
            {
                return obj[key.property];
            }
        }

        public function getRootEntity():Entity
        {
            var len:int = path.length;
            if (len > 1)
            {
                var key:CompositeKey = path[len-2] as CompositeKey;
                return key.associatedEntity;
            }
            return null;
        }

        public function Identity(hash:Object=null)
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