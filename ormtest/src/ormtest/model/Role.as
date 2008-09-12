package ormtest.model
{
    [Bindable]
    [Table(name="jobs")]
    public class Role
    {
        [Id(strategy="uid")]
        [Column(name="my_role_id")]
        public var id:String;

        [Column(name="title")]
        public var name:String;

    }
}