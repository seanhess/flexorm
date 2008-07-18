package ormtest.model
{
    [Bindable]
    public class Gallery
    {
        [Id]
        [Column(name="gallery_id")]
        public var id:int;

        [Column(name="gallery_name")]
        public var name:String;

        [ManyToOne(name="parent_id", cascade="save-update")]
        public var parent:Gallery;

    }
}