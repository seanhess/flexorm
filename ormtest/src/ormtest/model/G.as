package ormtest.model
{
    [Bindable]
    public class G
    {
        [Id]
        [ManyToOne]
        public var e:E;

        [Id]
        [ManyToOne]
        public var f:F;

        public var name:String;

    }
}