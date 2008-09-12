package nz.co.codec.flexorm.metamodel
{
    import nz.co.codec.flexorm.command.DeleteCommand;
    import nz.co.codec.flexorm.command.UpdateCommand;

    public class ListAssociation extends Association implements IListAssociation
    {

        /**
         * An instance of DeleteCommand to remove the link (not
         * the associated entity) in a cascade delete operation.
         */
        public var deleteCommand:DeleteCommand;

        public var updateFKAfterDeleteCommand:UpdateCommand;

        public var lazy:Boolean = false;

        public var indexed:Boolean = false;

        public var indexColumn:String;

        public var indexProperty:String;

        public var multiTyped:Boolean;

        private var _associatedTypes:Array = [];

        public function ListAssociation(hash:Object=null)
        {
            super(hash);
        }

        public function set associatedTypes(value:Array):void
        {
            _associatedTypes = value;
        }

        public function get associatedTypes():Array
        {
            return _associatedTypes;
        }

        public function getAssociatedEntity(entity:Entity):Entity
        {
            if (entity == null)
                return null;

            for each(var type:AssociatedType in _associatedTypes)
            {
                if (type.associatedEntity.equals(entity))
                    return entity;
            }
            return getAssociatedEntity(entity.superEntity);
        }

    }
}