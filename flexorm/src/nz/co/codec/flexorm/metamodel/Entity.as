package nz.co.codec.flexorm.metamodel
{
    import flash.utils.getQualifiedClassName;

    import mx.core.IUID;

    import nz.co.codec.flexorm.NamingStrategy;
    import nz.co.codec.flexorm.command.CreateCommand;
    import nz.co.codec.flexorm.command.CreateCommandAsync;
    import nz.co.codec.flexorm.command.DeleteCommand;
    import nz.co.codec.flexorm.command.FindAllCommand;
    import nz.co.codec.flexorm.command.InsertCommand;
    import nz.co.codec.flexorm.command.MarkForDeletionCommand;
    import nz.co.codec.flexorm.command.SelectCommand;
    import nz.co.codec.flexorm.command.SelectFkMapCommand;
    import nz.co.codec.flexorm.command.SelectIdMapCommand;
    import nz.co.codec.flexorm.command.SelectUnsynchronisedCommand;
    import nz.co.codec.flexorm.command.UpdateCommand;
    import nz.co.codec.flexorm.util.Inflector;
    import nz.co.codec.flexorm.util.StringUtils;

    public class Entity implements IUID
    {
        public var findAllCommand:FindAllCommand;

        public var selectCommand:SelectCommand;

        public var insertCommand:InsertCommand;

        public var updateCommand:UpdateCommand;

        public var deleteCommand:DeleteCommand;

        public var createCommand:CreateCommand;

        public var createCommandAsync:CreateCommandAsync;

        public var selectIdMapCommand:SelectIdMapCommand;

        public var selectFkMapCommand:SelectFkMapCommand;

        public var selectUnsynchronisedCommand:SelectUnsynchronisedCommand;

        public var markForDeletionCommand:MarkForDeletionCommand;

        public var indexCommands:Array;

        private var _cls:Class;

        private var _name:String;

        private var _root:String;

        private var _className:String;

        private var _table:String;

        private var _tableSingular:String;

        private var _fkColumn:String;

        private var _fkProperty:String;

        private var _identities:Array = [];

        public var keys:Array;

        public var superEntity:Entity;

        private var _fields:Array = [];

        private var _manyToOneAssociations:Array = [];

        private var _oneToManyAssociations:Array = [];

        private var _oneToManyInverseAssociations:Array = [];

        private var _manyToManyAssociations:Array = [];

        private var _manyToManyInverseAssociations:Array = [];

        private var _dependencies:Array = [];

        private var _namingStrategy:String;

        /**
         * Flag to indicate whether the loading of metadata for an entity has
         * been completed.
         */
        public var initialisationComplete:Boolean;

        public function Entity(
            c:Class,
            namingStrategy:String=NamingStrategy.UNDERSCORE_NAMES,
            name:String=null,
            root:String=null)
        {
            _cls = c;
            _className = getClassName(c);
            _namingStrategy = namingStrategy;

            if (namingStrategy == NamingStrategy.CAMEL_CASE_NAMES)
            {
                if (name)
                {
                    _tableSingular = Inflector.singularize(StringUtils.camelCase(name));
                }
                else
                {
                    _tableSingular = _className;
                }
                _table = _tableSingular;
                _fkColumn = StringUtils.startLowerCase(_tableSingular) + "Id";
                _fkProperty = _fkColumn;
            }
            else
            {
                if (name)
                {
                    _tableSingular = Inflector.singularize(StringUtils.underscore(name)).toLowerCase();
                    _table = Inflector.pluralize(StringUtils.underscore(name)).toLowerCase();
                }
                else
                {
                    _tableSingular = StringUtils.underscore(_className).toLowerCase();
                    _table = Inflector.pluralize(_tableSingular);
                }
                _fkColumn = _tableSingular + "_id";
                if (root)
                {
                    _fkProperty = StringUtils.startLowerCase(Inflector.singularize(StringUtils.camelCase(name))) + "Id";
                }
                else
                {
                    _fkProperty = StringUtils.startLowerCase(_className) + "Id";
                }
            }

            _name = isDynamicObject()? name : _className;
            _root = root;

            initialisationComplete = false;
        }

        public function set uid(value:String):void { }

        public function get uid():String
        {
            return _name;
        }

        public function get cls():Class
        {
            return _cls;
        }

        public function get name():String
        {
            return _name;
        }

        public function get root():String
        {
            return _root;
        }

        public function get className():String
        {
            return _className;
        }

        public function isDynamicObject():Boolean
        {
            return (_className == "Object");
        }

        public function get table():String
        {
            return _table;
        }

        public function get tableSingular():String
        {
            return _tableSingular;
        }

        public function get fkColumn():String
        {
            return _fkColumn;
        }

        public function get fkProperty():String
        {
            return _fkProperty;
        }

        public function addIdentity(value:IIdentity):void
        {
            _identities.push(value);
        }

        public function get identities():Array
        {
            return _identities;
        }

        /**
         * Convenience getter for an entity with a primary key
         */
        public function get pk():PrimaryIdentity
        {
            if (_identities && _identities.length == 1)
            {
                return PrimaryIdentity(_identities[0]);
            }
            return null;
        }

        public function hasCompositeKey():Boolean
        {
            return (_identities && _identities.length > 1)? true : false;
        }

        public function set fields(value:Array):void
        {
            _fields = value;
        }

        public function get fields():Array
        {
            return _fields;
        }

        public function addField(value:Field):void
        {
            _fields.push(value);
        }

        public function set manyToOneAssociations(value:Array):void
        {
            for each (var a:Association in value)
            {
                a.ownerEntity = this;
            }
            _manyToOneAssociations = value;
        }

        public function get manyToOneAssociations():Array
        {
            return _manyToOneAssociations;
        }

        public function addManyToOneAssociation(value:Association):void
        {
            value.ownerEntity = this;
            _manyToOneAssociations.push(value);
        }

        public function set oneToManyAssociations(value:Array):void
        {
            for each (var a:OneToManyAssociation in value)
            {
                a.ownerEntity = this;
            }
            _oneToManyAssociations = value;
        }

        public function get oneToManyAssociations():Array
        {
            return _oneToManyAssociations;
        }

        public function addOneToManyAssociation(value:OneToManyAssociation):void
        {
            value.ownerEntity = this;
            _oneToManyAssociations.push(value);
        }

        /**
         * a copy of the oneToManyAssociation set on
         * the map of the associated entity
         */
        public function set oneToManyInverseAssociations(value:Array):void
        {
            for each (var a:OneToManyAssociation in value)
            {
                a.ownerEntity = this;
            }
            _oneToManyInverseAssociations = value;
        }

        public function get oneToManyInverseAssociations():Array
        {
            return _oneToManyInverseAssociations;
        }

        public function addOneToManyInverseAssociation(value:OneToManyAssociation):void
        {
            value.ownerEntity = this;
            _oneToManyInverseAssociations.push(value);
        }

        public function set manyToManyAssociations(value:Array):void
        {
            for each (var a:ManyToManyAssociation in value)
            {
                a.ownerEntity = this;
            }
            _manyToManyAssociations = value;
        }

        public function get manyToManyAssociations():Array
        {
            return _manyToManyAssociations;
        }

        public function addManyToManyAssociation(value:ManyToManyAssociation):void
        {
            value.ownerEntity = this;
            _manyToManyAssociations.push(value);
        }

        public function set manyToManyInverseAssociations(value:Array):void
        {
            for each (var a:ManyToManyAssociation in value)
            {
                a.ownerEntity = this;
            }
            _manyToManyInverseAssociations = value;
        }

        public function get manyToManyInverseAssociations():Array
        {
            return _manyToManyInverseAssociations;
        }

        public function addManyToManyInverseAssociation(value:ManyToManyAssociation):void
        {
            value.ownerEntity = this;
            _manyToManyInverseAssociations.push(value);
        }

        public function set dependencies(value:Array):void
        {
            _dependencies = value;
        }

        public function get dependencies():Array
        {
            return _dependencies;
        }

        public function addDependency(value:Entity):void
        {
            _dependencies.push(value);
        }

        private function getClassName(c:Class):String
        {
            var qname:String = getQualifiedClassName(c);
            return qname.substring(qname.lastIndexOf(":") + 1);
        }

    }
}