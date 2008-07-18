package nz.co.codec.flexorm.metamodel
{
    import mx.utils.StringUtil;

    import nz.co.codec.flexorm.CascadeType;

    /**
     * Database column name of FK in table of associated entity
     * ( = class name of owning entity + '_id' by default);
     * e.g. 'contact_id', or
     *
     * in the case of a many-to-many association, the database column name
     * of the FK in the association table which links to the owner entity.
     *
     * The Many end of a One-to-many association may be called something
     * different than <owner entity classname>_id, such as when there are
     * multiple one-to-many associations to the same object having
     * different roles.
     */
    public class Association
    {
        /**
         * Property name
         */
        public var property:String;

        /**
         * Database column name of the FK to the owner Entity. Used if set
         * to override the 'className_id' naming convention.
         */
        public var fkColumn:String;

        /**
         * The parameter name corresponding to the fkColumn name.
         */
        public var fkProperty:String;

        /**
         * true if this association is the inverse end
         * of a bidirectional one-to-many association.
         */
        public var inverse:Boolean = false;

        public var constrain:Boolean;

        private var _ownerEntity:Entity;

        private var _associatedEntity:Entity;

        private var _cascadeType:String;

        public function set ownerEntity(value:Entity):void
        {
            _ownerEntity = value;
        }

        public function get ownerEntity():Entity
        {
            return _ownerEntity;
        }

        public function set associatedEntity(value:Entity):void
        {
            _associatedEntity = value;
        }

        public function get associatedEntity():Entity
        {
            return _associatedEntity;
        }

        /**
         * Valid values are:
         *   "save-update"
         *       save or update the associated entities on save of
         *       the owning entity,
         *   "delete"
         *       delete the associated entities on deletion of
         *       the owning entity,
         *   "all"
         *       support cascade save, update, and delete, and
         *   "none"
         *       do not cascade any changes to the associated entities
         */
        public function set cascadeType(value:String):void
        {
            if (value == null)
                return;

            var val:String = StringUtil.trim(value);
            if (val.length > 0)
            {
                _cascadeType = val;
            }
        }

        public function get cascadeType():String
        {
            return _cascadeType;
        }

        public function Association(hash:Object=null)
        {
            _cascadeType = CascadeType.SAVE_UPDATE;
            for (var key:String in hash)
            {
                if (hasOwnProperty(key))
                {
                    this[key] = hash[key];
                }
            }
        }

    }
}