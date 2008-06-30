package nz.co.codec.flexorm.metamodel
{
    public class Key
    {
        public var column:String;

        public var property:String;

        public var fkColumn:String;

        public var fkProperty:String;

        public var idpath:Array = [];

        public function getIdValue(obj:Object):int
        {
            if (obj == null)
                return 0;

            if (idpath.length == 0)
                return obj[property];

            return getIdVal(obj, idpath.concat());
        }

        private function getIdVal(obj:Object, path:Array):int
        {
            var identity:IIdentity = path.shift() as IIdentity;
            if (path.length > 0)
            {
                var keyVal:Object = obj[identity.property];
                return getIdVal(keyVal, path);
            }
            else
            {
                return obj[identity.property];
            }
        }

        public function getRootEntity():Entity
        {
            var len:int = idpath.length;
            if (len > 1)
            {
                var identity:CompositeIdentity = idpath[len - 2] as CompositeIdentity;
                return identity.associatedEntity;
            }
            return null;
        }

        public function Key(hash:Object=null)
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