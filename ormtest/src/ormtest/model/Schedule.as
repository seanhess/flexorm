package ormtest.model
{
    import mx.collections.IList;

    [Bindable]
    public class Schedule
    {
        [Id]
        [ManyToOne]
        public var student:Student;

        [Id]
        [ManyToOne]
        public var lesson:Lesson;

        public var lessonDate:Date;

        [OneToMany(type="ormtest.model.Resource")]
        public var resources:IList;

    }
}