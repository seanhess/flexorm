package ormtest.model
{
    import mx.core.IUID;

    [Bindable]
    [Table(name="Company")]
    public dynamic class Organisation implements IUID
    {
        [Id]
        public var id:int;

        public var name:String;

        [Transient]
        public function set uid(value:String):void
        {
            id = int(value);
        }

        public function get uid():String
        {
            return id.toString();
        }

    }
}