package ormtest.model
{
    import mx.collections.ArrayCollection;
    import mx.collections.IList;

    [Bindable]
    public class Folder extends FileObject
    {
        private var _children:IList;

        public function Folder()
        {
            super();
            name = "New Folder";
        }

        [OneToMany(type="ormtest.model.FileObject", fkColumn="parent_id", cascade="save-update", indexed="true")]
        public function set children(value:IList):void
        {
            _children = value;
        }

        public function get children():IList
        {
            return _children;
        }

        public function addChild(child:FileObject):void
        {
            if (_children == null)
            {
                _children = new ArrayCollection();
            }
            _children.addItem(child);
            child.parent = this;
        }

        public function removeChild(child:FileObject):void
        {
            if (_children)
            {
                _children.removeItemAt(_children.getItemIndex(child));
            }
        }

    }
}