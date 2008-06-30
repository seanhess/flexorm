package nz.co.codec.flexorm.metamodel
{
    import nz.co.codec.flexorm.command.DeleteCommand;

    public class ListAssociation extends Association implements IListAssociation
    {

        /**
         * An instance of DeleteCommand to remove the link (not
         * the associated entity) in a cascade delete operation.
         */
        public var deleteCommand:DeleteCommand;

        public var lazy:Boolean = false;

        public var indexed:Boolean = false;

        public var indexColumn:String;

        public var indexProperty:String;

        public function ListAssociation(hash:Object=null)
        {
            super(hash);
        }

    }
}