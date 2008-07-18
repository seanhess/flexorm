package ormtest.model2
{
    [Bindable]
    [Table(name="human_being")]
    public class Person
    {
        [Id]
        [Column(name="person_id")]
        public var id:int;

        public var emailAddr:String;

    }
}