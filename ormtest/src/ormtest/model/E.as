package ormtest.model
{
    [Bindable]
    public class E
    {
        [Id]
        [ManyToOne]
        public var a:A;

        [Id]
        [ManyToOne]
        public var b:B;

        public var name:String;

    }
}