package nz.co.codec.flexorm.metamodel
{
    public class Field
    {
        public var property:String;

        public var column:String;

        public var type:String;

        public function Field(hash:Object = null)
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