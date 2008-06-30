package ormtest.model
{
    [Bindable]
    [Table(name="aas")]
    public class A
    {
        [Id]
        public var id:int;

        public var name:String;

    }
}