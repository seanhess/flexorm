package ormtest.model
{
    [Bindable]
    public class FileObject
    {
        public var id:int;

        public var name:String;

        [ManyToOne(name="parent_id", inverse="true")]
        public var parent:FileObject;

        public function removeSelf():FileObject
        {
            if (parent)
            {
                Folder(parent).removeChild(this);
            }
            return this;
        }

        public function getIndex():int
        {
            return parent? Folder(parent).children.getItemIndex(this) : 0;
        }

    }
}