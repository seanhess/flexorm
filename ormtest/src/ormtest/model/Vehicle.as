package ormtest.model
{
    import mx.collections.ArrayCollection;
    import mx.collections.IList;

    [Bindable]
    public class Vehicle
    {
        public var id:int;

        public var name:String;

        [OneToMany(type="ormtest.model.Part", cascade="save-update", lazy="true")]
        public var parts:IList;

        public function Vehicle()
        {
            parts = new ArrayCollection();
        }

    }
}