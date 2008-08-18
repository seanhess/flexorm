package ormtest.model
{
    [Bindable]
    public class Document extends FileObject
    {
        public function Document()
        {
            super();
            name = "New Document";
        }

    }
}