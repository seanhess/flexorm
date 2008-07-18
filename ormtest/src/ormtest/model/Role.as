package ormtest.model
{
    [Bindable]
    [Table(name="jobs")]
    public class Role
    {
        [Id]
        [Column(name="my_role_id")]
        public var id:int;

        [Column(name="title")]
        public var name:String;

    }
}