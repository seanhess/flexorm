package nz.co.codec.flexorm.metamodel
{
    import mx.core.IUID;

    import nz.co.codec.flexorm.command.CreateAsynCommand;
    import nz.co.codec.flexorm.command.CreateSynCommand;
    import nz.co.codec.flexorm.command.DeleteCommand;
    import nz.co.codec.flexorm.command.InsertCommand;
    import nz.co.codec.flexorm.command.SelectCommand;
    import nz.co.codec.flexorm.command.SelectMaxRgtCommand;
    import nz.co.codec.flexorm.command.SelectNestedSetTypesCommand;
    import nz.co.codec.flexorm.command.UpdateCommand;
    import nz.co.codec.flexorm.command.UpdateNestedSetsCommand;
    import nz.co.codec.flexorm.command.UpdateNestedSetsLeftBoundaryCommand;
    import nz.co.codec.flexorm.command.UpdateNestedSetsRightBoundaryCommand;

    public class Entity implements IUID
    {
        public var selectCommand:SelectCommand;

        public var selectAllCommand:SelectCommand;

        public var selectSubtypeCommand:SelectCommand;

        public var selectNestedSetsCommand:SelectCommand;

        public var selectNestedSetTypesCommand:SelectNestedSetTypesCommand;

        public var insertCommand:InsertCommand;

        public var updateCommand:UpdateCommand;

        public var deleteCommand:DeleteCommand;

        public var markForDeletionCommand:UpdateCommand;

        public var createSynCommand:CreateSynCommand;

        public var createAsynCommand:CreateAsynCommand;

        public var selectServerKeyMapCommand:SelectCommand;

        public var selectKeysCommand:SelectCommand;

        public var selectUpdatedCommand:SelectCommand;

        public var updateVersionCommand:UpdateCommand;

        public var indexCommands:Array;

        public var identities:Array;

        public var superEntity:Entity;

        public var hierarchical:Boolean;

        private var _selectMaxRgtCommand:SelectMaxRgtCommand;

        private var _updateLeftBoundaryCommand:UpdateNestedSetsLeftBoundaryCommand;

        private var _updateRightBoundaryCommand:UpdateNestedSetsRightBoundaryCommand;

        private var _updateNestedSetsCommand:UpdateNestedSetsCommand;

        private var _isSuperEntity:Boolean;

        private var _cls:Class;

        private var _className:String;

        private var _name:String;

        private var _root:String;

        private var _table:String;

        private var _tableSingular:String;

        private var _fkColumn:String;

        private var _fkProperty:String;

        private var _parentProperty:String;

        private var _keys:Array;

        private var _subEntities:Array;

        private var _fields:Array;

        private var _manyToOneAssociations:Array;

        private var _oneToManyAssociations:Array;

        private var _oneToManyInverseAssociations:Array;

        private var _manyToManyAssociations:Array;

        private var _manyToManyInverseAssociations:Array;

        private var _dependencies:Array;

        private var _initialisationComplete:Boolean;

        private var selectCommandBuildIncomplete:Boolean;

        public function Entity()
        {
            _isSuperEntity = false;
            _keys = [];
            _subEntities = [];
            _fields = [];
            _manyToOneAssociations = [];
            _oneToManyAssociations = [];
            _oneToManyInverseAssociations = [];
            _manyToManyAssociations = [];
            _manyToManyInverseAssociations = [];
            _dependencies = [];
            _initialisationComplete = false;
            selectCommandBuildIncomplete = true;
        }

        /**
         * Flag to indicate whether the loading of metadata for an entity has
         * been completed.
         */
        public function set initialisationComplete(value:Boolean):void
        {
            if (_className == null || _name == null || _table == null)
                throw new Error("Entity not initialised. ");

            _initialisationComplete = value;
        }

        public function get initialisationComplete():Boolean
        {
            return _initialisationComplete;
        }

        public function set uid(value:String):void { }

        public function get uid():String
        {
            return _name;
        }

        public function set selectMaxRgtCommand(value:SelectMaxRgtCommand):void
        {
            _selectMaxRgtCommand = value;
        }

        public function get selectMaxRgtCommand():SelectMaxRgtCommand
        {
            if (!_selectMaxRgtCommand && superEntity)
                return superEntity.selectMaxRgtCommand;
            else
                return _selectMaxRgtCommand;
        }

        public function set updateLeftBoundaryCommand(value:UpdateNestedSetsLeftBoundaryCommand):void
        {
            _updateLeftBoundaryCommand = value;
        }

        public function get updateLeftBoundaryCommand():UpdateNestedSetsLeftBoundaryCommand
        {
            if (!_updateLeftBoundaryCommand && superEntity)
                return superEntity.updateLeftBoundaryCommand;
            else
                return _updateLeftBoundaryCommand;
        }

        public function set updateRightBoundaryCommand(value:UpdateNestedSetsRightBoundaryCommand):void
        {
            _updateRightBoundaryCommand = value;
        }

        public function get updateRightBoundaryCommand():UpdateNestedSetsRightBoundaryCommand
        {
            if (!_updateRightBoundaryCommand && superEntity)
                return superEntity.updateRightBoundaryCommand;
            else
                return _updateRightBoundaryCommand;
        }

        public function set updateNestedSetsCommand(value:UpdateNestedSetsCommand):void
        {
            _updateNestedSetsCommand = value;
        }

        public function get updateNestedSetsCommand():UpdateNestedSetsCommand
        {
            if (!_updateNestedSetsCommand && superEntity)
                return superEntity.updateNestedSetsCommand;
            else
                return _updateNestedSetsCommand;
        }

        public function isSuperEntity():Boolean
        {
            return _isSuperEntity;
        }

        public function set cls(value:Class):void
        {
            _cls = value;
        }

        public function get cls():Class
        {
            return _cls;
        }

        public function set className(value:String):void
        {
            _className = value;
        }

        public function get className():String
        {
            return _className;
        }

        public function isDynamicObject():Boolean
        {
            return ("Object" == _className);
        }

        public function set name(value:String):void
        {
            _name = value;
        }

        public function get name():String
        {
            return _name;
        }

        public function set root(value:String):void
        {
            _root = value;
        }

        public function get root():String
        {
            return _root;
        }

        public function set table(value:String):void
        {
            _table = value;
        }

        public function get table():String
        {
            return _table;
        }

        public function set tableSingular(value:String):void
        {
            _tableSingular = value;
        }

        public function get tableSingular():String
        {
            return _tableSingular;
        }

        public function set fkColumn(value:String):void
        {
            _fkColumn = value;
        }

        public function get fkColumn():String
        {
            return _fkColumn;
        }

        public function set fkProperty(value:String):void
        {
            _fkProperty = value;
        }

        public function get fkProperty():String
        {
            return _fkProperty;
        }

        public function set parentProperty(value:String):void
        {
            _parentProperty = value;
        }

        public function get parentProperty():String
        {
            if (!_parentProperty && superEntity)
                return superEntity.parentProperty;
            else
                return _parentProperty;
        }

        public function set keys(value:Array):void
        {
            _keys = value;
        }

        public function addKey(value:Key):void
        {
            _keys.push(value);
        }

        public function get keys():Array
        {
            return _keys;
        }

        /**
         * Convenience getter for an entity with a Primary Key
         */
        public function get pk():PrimaryKey
        {
            if (_keys && _keys.length == 1)
            {
                return PrimaryKey(_keys[0]);
            }
            return null;
        }

        public function hasCompositeKey():Boolean
        {
            return (_keys && _keys.length > 1) ? true : false;
        }

        public function set fields(value:Array):void
        {
            _fields = value;
        }

        public function addField(value:Field):void
        {
            _fields.push(value);
        }

        public function get fields():Array
        {
            return _fields;
        }

        public function getColumn(property:String):Object
        {
            for each(var field:Field in fields)
            {
                if (field.property == property)
                {
                    return { table: table, column: field.column };
                }
            }
            if (superEntity)
                return superEntity.getColumn(property);
            return null;
        }

        public function set manyToOneAssociations(value:Array):void
        {
            for each (var a:Association in value)
            {
                a.ownerEntity = this;
            }
            _manyToOneAssociations = value;
        }

        public function addManyToOneAssociation(value:Association):void
        {
            value.ownerEntity = this;
            _manyToOneAssociations.push(value);
        }

        public function get manyToOneAssociations():Array
        {
            return _manyToOneAssociations;
        }

        public function set oneToManyAssociations(value:Array):void
        {
            for each (var a:OneToManyAssociation in value)
            {
                a.ownerEntity = this;
            }
            _oneToManyAssociations = value;
        }

        public function addOneToManyAssociation(value:OneToManyAssociation):void
        {
            value.ownerEntity = this;
            _oneToManyAssociations.push(value);
        }

        public function get oneToManyAssociations():Array
        {
            return _oneToManyAssociations;
        }

        /**
         * A copy of the oneToManyAssociation set on the map of the associated
         * entity.
         */
        public function set oneToManyInverseAssociations(value:Array):void
        {
            for each (var a:OneToManyAssociation in value)
            {
                a.ownerEntity = this;
            }
            _oneToManyInverseAssociations = value;
        }

        public function addOneToManyInverseAssociation(value:OneToManyAssociation):void
        {
//            value.ownerEntity = this;
            _oneToManyInverseAssociations.push(value);
        }

        public function get oneToManyInverseAssociations():Array
        {
            return _oneToManyInverseAssociations;
        }

        public function set manyToManyAssociations(value:Array):void
        {
            for each (var a:ManyToManyAssociation in value)
            {
                a.ownerEntity = this;
            }
            _manyToManyAssociations = value;
        }

        public function addManyToManyAssociation(value:ManyToManyAssociation):void
        {
            value.ownerEntity = this;
            _manyToManyAssociations.push(value);
        }

        public function get manyToManyAssociations():Array
        {
            return _manyToManyAssociations;
        }

        public function set manyToManyInverseAssociations(value:Array):void
        {
            for each (var a:ManyToManyAssociation in value)
            {
                a.ownerEntity = this;
            }
            _manyToManyInverseAssociations = value;
        }

        public function addManyToManyInverseAssociation(value:ManyToManyAssociation):void
        {
            value.ownerEntity = this;
            _manyToManyInverseAssociations.push(value);
        }

        public function get manyToManyInverseAssociations():Array
        {
            return _manyToManyInverseAssociations;
        }

        public function set dependencies(value:Array):void
        {
            _dependencies = value;
        }

        public function addDependency(value:Entity):void
        {
            _dependencies.push(value);
        }

        public function get dependencies():Array
        {
            return _dependencies;
        }

        public function set subEntities(value:Array):void
        {
            _subEntities = value;
        }

        public function addSubEntity(entity:Entity):void
        {
            _subEntities.push(entity);
            entity.superEntity = this;
            _isSuperEntity = true;
        }

        public function get subEntities():Array
        {
            return _subEntities;
        }

        public function buildSelectCommands():void
        {
            if (superEntity && selectCommandBuildIncomplete)
            {
                superEntity.buildSelectCommands();
                selectCommand.mergeColumns(superEntity.selectCommand.columns);
                selectSubtypeCommand.mergeColumns(superEntity.selectCommand.columns);
                selectAllCommand.mergeColumns(superEntity.selectAllCommand.columns);
                if (selectNestedSetsCommand)
                {
                    selectNestedSetsCommand.mergeColumns(superEntity.selectNestedSetsCommand.columns);
                    selectNestedSetsCommand.mergeFilters(superEntity.selectNestedSetsCommand.filters);
                    selectNestedSetsCommand.mergeSorts(superEntity.selectNestedSetsCommand.sorts);
                }
                if (hasCompositeKey())
                {
                    for each(var identity:Identity in identities)
                    {
                        selectCommand.addJoin(superEntity.table, identity.column, identity.column);
                        selectSubtypeCommand.addJoin(superEntity.table, identity.column, identity.column);
                        selectAllCommand.addJoin(superEntity.table, identity.column, identity.column);
                        if (selectNestedSetsCommand)
                            selectNestedSetsCommand.addJoin(superEntity.table, identity.column, identity.column);
                    }

                }
                else
                {
                    selectCommand.addJoin(superEntity.table, pk.column, superEntity.pk.column);
                    selectSubtypeCommand.addJoin(superEntity.table, pk.column, superEntity.pk.column);
                    selectAllCommand.addJoin(superEntity.table, pk.column, superEntity.pk.column);
                    if (selectNestedSetsCommand)
                        selectNestedSetsCommand.addJoin(superEntity.table, pk.column, superEntity.pk.column);
                }
                selectCommandBuildIncomplete = false;
            }
        }

        public function equals(other:*):Boolean
        {
            if (other && (other is Entity) && other.name)
            {
                if (other.name == _name)
                {
                    return true;
                }
            }
            return false;
        }

    }
}