package ormtest.model
{
    [Bindable]
    public class F
    {
        [Id]
        [ManyToOne]
        public var c:C;

        [Id]
        [ManyToOne]
        public var d:D;

        public var name:String;

    }
}