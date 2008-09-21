package nz.co.codec.flexorm
{
    import flash.data.SQLConnection;
    import flash.utils.describeType;
    import flash.utils.getDefinitionByName;
    import flash.utils.getQualifiedClassName;

    import mx.collections.ArrayCollection;
    import mx.collections.IList;
    import mx.utils.StringUtil;

    import nz.co.codec.flexorm.command.CreateAsynCommand;
    import nz.co.codec.flexorm.command.CreateIndexCommand;
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
    import nz.co.codec.flexorm.criteria.SQLCondition;
    import nz.co.codec.flexorm.criteria.Sort;
    import nz.co.codec.flexorm.metamodel.AssociatedType;
    import nz.co.codec.flexorm.metamodel.Association;
    import nz.co.codec.flexorm.metamodel.CompositeKey;
    import nz.co.codec.flexorm.metamodel.Entity;
    import nz.co.codec.flexorm.metamodel.Field;
    import nz.co.codec.flexorm.metamodel.IDStrategy;
    import nz.co.codec.flexorm.metamodel.IHierarchicalObject;
    import nz.co.codec.flexorm.metamodel.Identity;
    import nz.co.codec.flexorm.metamodel.Key;
    import nz.co.codec.flexorm.metamodel.ManyToManyAssociation;
    import nz.co.codec.flexorm.metamodel.OneToManyAssociation;
    import nz.co.codec.flexorm.metamodel.PrimaryKey;
    import nz.co.codec.flexorm.util.Inflector;
    import nz.co.codec.flexorm.util.StringUtils;

    public class EntityIntrospector
    {
        private var _schema:String;

        private var _sqlConnection:SQLConnection;

        private var _entityMap:Object;

        private var _debugLevel:int;

        private var _prefs:Object;

        private var deferred:Array;

        private var awaitingKeyResolution:Array;

        private var metaTableCreated:Boolean;

        private var missingKey:Boolean;

        public function EntityIntrospector(
            schema:String,
            sqlConnection:SQLConnection,
            entityMap:Object,
            debugLevel:int,
            prefs:Object=null)
        {
            _schema = schema;
            _sqlConnection = sqlConnection;
            _entityMap = entityMap;
            _debugLevel = debugLevel;
            _prefs = prefs;
            deferred = [];
            awaitingKeyResolution = [];
            metaTableCreated = false;
        }

        public function set sqlConnection(value:SQLConnection):void
        {
            _sqlConnection = value;
        }

        public function set entityMap(value:Object):void
        {
            _entityMap = value;
        }

        public function set debugLevel(value:int):void
        {
            _debugLevel = value;
        }

        public function set prefs(value:Object):void
        {
            _prefs = value;
        }

        public function loadMetadata(cls:Class, executor:IExecutor=null):Entity
        {
            deferred.length = 0;
            var entity:Entity = loadMetadataForClass(cls);
            var entities:Array = [];
            entities.push(entity);
            while (deferred.length > 0)
            {
                entities.push(loadMetadataForClass(deferred.pop() as Class));
            }
            while (awaitingKeyResolution.length > 0)
            {
                var e:Entity = awaitingKeyResolution.pop() as Entity;
                e.keys = e.superEntity.keys;
            }
            populateIdentities(entities);
            buildSQL(entities);
            buildSelectHierarchyCommand(entities);
            if (executor)
            {
                createTablesAsyn(sequenceEntitiesForTableCreation(entities), executor);
            }
            else
            {
                createTables(sequenceEntitiesForTableCreation(entities));
            }
            return entity;
        }

        private function populateIdentities(entities:Array):void
        {
            for each(var entity:Entity in entities)
            {
                entity.identities = getIdentities(entity);
            }
        }

        private function buildSQL(entities:Array):void
        {
            for each(var entity:Entity in entities)
            {
                buildSQLCommands(entity);
            }
        }

        private function buildSelectHierarchyCommand(entities:Array):void
        {
            for each(var entity:Entity in entities)
            {
                entity.buildSelectCommands();
            }
        }

        private function createTables(createSequence:Array):void
        {
            var associationTableCreateCommands:Array = [];
            var entity:Entity;
            for each(entity in createSequence)
            {
                for each(var a:ManyToManyAssociation in entity.manyToManyAssociations)
                {
                    associationTableCreateCommands.push(a.createSynCommand);
                }
                entity.createSynCommand.execute();
            }

            // create association tables last
            for each(var command:CreateSynCommand in associationTableCreateCommands)
            {
                command.execute();
            }

            // create indexes
            for each(entity in createSequence)
            {
                for each(var indexCommand:CreateIndexCommand in entity.indexCommands)
                {
                    indexCommand.execute();
                }
            }

            if (_prefs.syncSupport && !metaTableCreated)
                createMetaTable(); // for synchronisation
        }

        private function createTablesAsyn(createSequence:Array, executor:IExecutor):void
        {
            var associationTableCreateCommands:Array = [];
            for each(var entity:Entity in createSequence)
            {
                for each(var a:ManyToManyAssociation in entity.manyToManyAssociations)
                {
                    associationTableCreateCommands.push(a.createAsynCommand);
                }
                executor.add(entity.createAsynCommand);
            }

            // create association tables last
            for each(var command:CreateAsynCommand in associationTableCreateCommands)
            {
                executor.add(command);
            }

            if (_prefs.syncSupport && !metaTableCreated)
                createMetaTableAsyn(executor); // for synchronisation
        }

        private function createMetaTable():void
        {
            var createCommand:CreateSynCommand = new CreateSynCommand(_sqlConnection, _schema,"sync_status", _debugLevel);
            createCommand.addColumn("entity", SQLType.STRING);
            createCommand.addColumn("last_sync_at", SQLType.DATE);
            createCommand.execute();
            metaTableCreated = true;
        }

        private function createMetaTableAsyn(executor:IExecutor):void
        {
            var createAsynCmd:CreateAsynCommand = new CreateAsynCommand(_sqlConnection, _schema, "sync_status", _debugLevel);
            createAsynCmd.addColumn("entity", SQLType.STRING);
            createAsynCmd.addColumn("last_sync_at", SQLType.DATE);
            executor.add(createAsynCmd);
            metaTableCreated = true;
        }

        /**
         * Sequence entities so that referential integrity is maintained as
         * tables are created.
         */
        private function sequenceEntitiesForTableCreation(entities:Array):Array
        {
            var createSeq:Array = [].concat(entities);
            for each(var entity:Entity in entities)
            {
                var i:int = createSeq.indexOf(entity);
                var k:int = 0;
                for each(var e:Entity in entity.dependencies)
                {
                    var j:int = createSeq.indexOf(e) + 1;
                    k = (j > k) ? j : k;
                }
                if (k != i)
                {
                    createSeq.splice(k, 0, entity);
                    if (k < i)
                    {
                        createSeq.splice(i + 1, 1);
                    }
                    else
                    {
                        createSeq.splice(i, 1);
                    }
                }
            }
            return createSeq;
        }

        private function loadMetadataForClass(cls:Class):Entity
        {
            var cn:String = getClassName(cls);
            var c_n:String = StringUtils.underscore(cn).toLowerCase();
            var entity:Entity = getEntity(cls, cn, c_n);
            var xml:XML = describeType(new cls());
            var table:String = StringUtil.trim(xml.metadata.(@name == Tags.ELEM_TABLE).arg.(@key == Tags.ATTR_NAME).@value);
            var tableSingular:String;
            if (table == null || table.length == 0)
            {
                if (usingCamelCaseNames())
                {
                    tableSingular = cn;
                    table = cn;
                }
                else
                {
                    tableSingular = c_n;
                    table = Inflector.pluralize(c_n);
                }
            }
            else
            {
                tableSingular = Inflector.singularize(table);
            }
            entity.table = table;
            entity.tableSingular = tableSingular;

            if (new cls() is IHierarchicalObject)
                entity.hierarchical = true;

            var qname:String = getQualifiedClassName(cls);
            var i:int = qname.indexOf("::");
            var pkg:String = (i > 0) ? qname.substring(0, i) : null;
            extractSuperType(pkg, xml, entity);

            missingKey = true;
            var defaultKey:PrimaryKey = null;

            var variables:XMLList = xml.accessor;
            for each(var v:Object in variables)
            {
                // Skip properties of superclass
                var declaredBy:String = v.@declaredBy.toString();
                if (declaredBy.search(new RegExp(entity.className, "i")) == -1)
                    continue;

                var type:Class = getClass(v.@type); // associated object class
                var typeQName:String = getQualifiedClassName(type);
                i = typeQName.lastIndexOf(":");
                var typePkg:String = (i > 0) ? typeQName.substring(0, i - 1) : null;
                var property:String = v.@name.toString();
                var column:String;

                if (v.metadata.(@name == Tags.ELEM_COLUMN).length() > 0)
                {
                    column = extractColumn(v, entity, property);
                }
                else if (v.metadata.(@name == Tags.ELEM_MANY_TO_ONE).length() > 0)
                {
                    extractManyToOneAssociation(v, entity, property);
                }
                else if (v.metadata.(@name == Tags.ELEM_ONE_TO_MANY).length() > 0)
                {
                    extractOneToManyAssociation(v, entity, property, c_n);
                }
                else if (v.metadata.(@name == Tags.ELEM_MANY_TO_MANY).length() > 0)
                {
                    extractManyToManyAssociation(v, entity, property, c_n);
                }
                else if (v.metadata.(@name == Tags.ELEM_TRANSIENT).length() > 0)
                {
                    // skip
                }

                // The property has no annotation ----------------------------

                // if type is in the same package as cls
                else if (typePkg == pkg) // then infer many-to-one association
                {
                    extractInferredManyToOneAssociation(entity, type, property);
                }

                // if type is a list and has a property name that matches
                // another entity (depends on the metadata for that entity
                // having being loaded already)
                else if ((type is IList) && isEntity(property))
                {
                    extractInferredOneToManyAssociation(entity, type, property);
                }

                else
                {
                    column = usingCamelCaseNames() ?
                        property : StringUtils.underscore(property).toLowerCase();

                    entity.addField(new Field(
                    {
                        property: property,
                        column  : column,
                        type    : getSQLType(v.@type)
                    }));

                    if ((defaultKey == null) && StringUtils.endsWith(property.toLowerCase(), "id"))
                    {
                        defaultKey = new PrimaryKey(
                        {
                            column  : column,
                            property: property,
                            strategy: getIDStrategy(v.@type)
                        });
                    }
                }

                if (missingKey && v.metadata.(@name == Tags.ELEM_ID).length() > 0)
                {
                    var strategy:String = StringUtil.trim(v.metadata.(@name == Tags.ELEM_ID).arg.(@key == Tags.ATTR_ID_STRATEGY).@value.toString());
                    if (strategy == null || strategy.length == 0)
                    {
                        strategy = getIDStrategy(v.@type);
                    }
                    else if (strategy != getIDStrategy(v.@type))
                        throw new Error("The data type '" + v.@type + "' of the ID for " + entity.name +
                                        " is not compatible with the '" + strategy + "' strategy. ");

                    entity.addKey(new PrimaryKey(
                    {
                        column  : column,
                        property: property,
                        strategy: strategy
                    }));
                    missingKey = false;
                }
            }

            if (missingKey)
            {
                if (defaultKey == null)
                {
                    if (entity.superEntity)
                    {
                        awaitingKeyResolution.push(entity);
                    }
                    else
                    {
                        throw new Error("No ID specified for " + entity.name + ". ");
                    }
                }
                else
                {
                    entity.addKey(defaultKey);
                }
            }

            entity.initialisationComplete = true;
            return entity;
        }

        private function extractSuperType(pkg:String, xml:XML, entity:Entity):void
        {
            var superType:String = xml.extendsClass[0].@type.toString();
            var i:int = superType.indexOf("::");
            var superPkg:String = (i > 0) ? superType.substring(0, i) : null;
            var inheritsFrom:String = StringUtil.trim(xml.metadata.(@name == Tags.ELEM_TABLE).arg.(@key == Tags.ATTR_INHERITS_FROM).@value.toString());

            // Check if the supplied qualified class name is formatted as
            // pkg.className and convert it to pkg::className
            if (inheritsFrom && inheritsFrom.length > 0)
            {
                i = inheritsFrom.indexOf("::");
                if (i == -1)
                {
                    i = inheritsFrom.lastIndexOf(".");
                    if (i > 0)
                    {
                        inheritsFrom = inheritsFrom.substring(0, i) + "::" + inheritsFrom.substring(i + 1);
                    }
                }
            }

            // if superType has the same package as entity and is not Object
            if (((pkg == superPkg) && (superType != "Object")) || (superType == inheritsFrom))
            {
                var cls:Class = getClass(superType);
                var cn:String = getClassName(cls);
                var superEntity:Entity = _entityMap[cn];
                if (superEntity == null)
                {
                    superEntity = getEntity(cls, cn);
                    deferred.push(cls);
                }
                superEntity.addSubEntity(entity);
                entity.addDependency(superEntity);
            }
        }

        private function extractColumn(v:Object, entity:Entity, property:String):String
        {
            var column:String = StringUtil.trim(v.metadata.(@name == Tags.ELEM_COLUMN).arg.(@key == Tags.ATTR_NAME).@value.toString());
            if (column == null || column.length == 0)
            {
                column = usingCamelCaseNames() ?
                    property : StringUtils.underscore(property).toLowerCase();
            }
            entity.addField(new Field(
            {
                property: property,
                column  : column,
                type    : getSQLType(v.@type)
            }));
            return column;
        }

        private function extractManyToOneAssociation(v:Object, entity:Entity, property:String):void
        {
            var metadata:XMLList = v.metadata.(@name == Tags.ELEM_MANY_TO_ONE);
            var fkColumn:String = StringUtil.trim(metadata.arg.(@key == Tags.ATTR_NAME).@value.toString());
            var cascadeType:String = StringUtil.trim(metadata.arg.(@key == Tags.ATTR_CASCADE).@value.toString());
            var inverse:Boolean = StringUtils.parseBoolean(metadata.arg.(@key == Tags.ATTR_INVERSE).@value.toString(), false);
            var constrain:Boolean = StringUtils.parseBoolean(metadata.arg.(@key == Tags.ATTR_CONSTRAIN).@value.toString(), true);

            var type:Class = getClass(v.@type); // associated object class
            var cn:String = getClassName(type); // class name of associated object
            var associatedEntity:Entity = _entityMap[cn];
            if (associatedEntity == null)
            {
                associatedEntity = getEntity(type, cn);
                deferred.push(type);
            }

            var fkProperty:String;
            if (fkColumn == null || fkColumn.length == 0)
            {
                fkColumn = associatedEntity.fkColumn;
                fkProperty = associatedEntity.fkProperty;
            }
            else
            {
                // As there may be more than one Many-to-one association of the
                // same type
                fkProperty = StringUtils.camelCase(fkColumn);
            }

            if (v.metadata.(@name == Tags.ELEM_ID).length() > 0)
            {
                entity.addKey(new CompositeKey(
                {
                    property        : property,
                    associatedEntity: associatedEntity
                }));
                cascadeType = CascadeType.NONE;
                missingKey = false;
            }

            var associationIsHierarchical:Boolean = false;
            if (new associatedEntity.cls() is IHierarchicalObject)
            {
                entity.parentProperty = property;
                associationIsHierarchical = true;
            }

            entity.addManyToOneAssociation(new Association(
            {
                property        : property,
                fkColumn        : fkColumn,
                fkProperty      : fkProperty,
                associatedEntity: associatedEntity,
                cascadeType     : cascadeType,
                inverse         : inverse,
                constrain       : constrain,
                hierarchical    : associationIsHierarchical
            }));
            entity.addDependency(associatedEntity);
        }

        private function extractInferredManyToOneAssociation(entity:Entity, type:Class, property:String):void
        {
            var cn:String = getClassName(type);// classname of associated object
            var associatedEntity:Entity = _entityMap[cn];
            if (associatedEntity == null)
            {
                associatedEntity = getEntity(type, cn);
                deferred.push(type);
            }

            entity.addManyToOneAssociation(new Association(
            {
                property        : property,
                associatedEntity: associatedEntity
            }));
            entity.addDependency(associatedEntity);
        }

        private function extractOneToManyAssociation(v:Object, entity:Entity, property:String, c_n:String):void
        {
            var metadata:XMLList = v.metadata.(@name == Tags.ELEM_ONE_TO_MANY);
            var typeVal:String = StringUtil.trim(metadata.arg.(@key == Tags.ATTR_TYPE).@value.toString());
            if (typeVal == null || typeVal.length == 0)
                throw new Error("Attribute 'type' must be set on the [OneToMany] annotation. ");

            var fkColumn:String = StringUtil.trim(metadata.arg.(@key == Tags.ATTR_FK_COLUMN).@value.toString());
            var cascadeType:String = StringUtil.trim(metadata.arg.(@key == Tags.ATTR_CASCADE).@value.toString());
            var lazy:Boolean = StringUtils.parseBoolean(metadata.arg.(@key == Tags.ATTR_LAZY).@value.toString(), false);
            var inverse:Boolean = StringUtils.parseBoolean(metadata.arg.(@key == Tags.ATTR_INVERSE).@value.toString(), false);
            var constrain:Boolean = StringUtils.parseBoolean(metadata.arg.(@key == Tags.ATTR_CONSTRAIN).@value.toString(), true);
            var indexed:Boolean = StringUtils.parseBoolean(metadata.arg.(@key == Tags.ATTR_INDEXED).@value.toString(), false);
            var indexColumn:String = StringUtil.trim(metadata.arg.(@key == Tags.ATTR_INDEX_COLUMN).@value.toString());
            var indexProperty:String = null;

            var fkProperty:String;
            if (fkColumn == null || fkColumn.length == 0)
            {
                fkColumn = entity.fkColumn;
                fkProperty = entity.fkProperty;
            }
            else
            {
                fkProperty = StringUtils.camelCase(fkColumn);
            }

            if (indexed && (indexColumn == null || indexColumn.length == 0))
            {
                indexColumn = c_n + "_idx";
            }
            else
            {
                indexColumn = null;
            }

            if (indexColumn)
            {
                indexProperty = StringUtils.camelCase(indexColumn);
            }

            var types:Array = typeVal.split(/\d*\,\d*/);
            var associatedTypes:Array = [];

            var a:OneToManyAssociation = new OneToManyAssociation(
            {
                property       : property,
                multiTyped     : (types.length > 1),
                associatedTypes: associatedTypes,
                cascadeType    : cascadeType,
                lazy           : lazy,
                inverse        : inverse,
                constrain      : constrain,
                fkColumn       : fkColumn,
                fkProperty     : fkProperty,
                indexed        : indexed,
                indexColumn    : indexColumn,
                indexProperty  : indexProperty
            });

            entity.addOneToManyAssociation(a); // also sets the ownerEntity as entity

            for each(var t:String in types)
            {
                var type:Class = getClass(t);
                var cn:String = getClassName(type);
                var associatedEntity:Entity = _entityMap[cn];
                if (associatedEntity == null)
                {
                    associatedEntity = getEntity(type, cn);
                    deferred.push(type);
                }

                // TODO there must be a cleaner way to check this
                if (new associatedEntity.cls() is IHierarchicalObject)
                {
                    a.hierarchical = true;
                    a.indexed = false;
                    a.indexColumn = "lft";
                    a.indexProperty = "lft";
                }

                var associatedType:AssociatedType = new AssociatedType();
                associatedType.associatedEntity = associatedEntity;
                associatedTypes.push(associatedType);
                associatedEntity.addOneToManyInverseAssociation(a);
                associatedEntity.addDependency(entity);
            }
        }

        private function extractInferredOneToManyAssociation(entity:Entity, type:Class, property:String):void
        {
            var cn:String = getClassName(type);// classname of associated object
            var associatedEntity:Entity = _entityMap[cn];
            if (associatedEntity == null)
            {
                associatedEntity = getEntity(type, cn);
                deferred.push(type);
            }

            var a:OneToManyAssociation = new OneToManyAssociation(
            {
                property        : property,
                associatedEntity: associatedEntity,
                fkColumn        : entity.fkColumn,
                fkProperty      : entity.fkProperty
            });
            associatedEntity.addOneToManyInverseAssociation(a);
            entity.addOneToManyAssociation(a); // also sets the ownerEntity as entity
            associatedEntity.addDependency(entity);
        }

        private function extractManyToManyAssociation(v:Object, entity:Entity, property:String, c_n:String):void
        {
            var metadata:XMLList = v.metadata.(@name == Tags.ELEM_MANY_TO_MANY);
            var type:Class = getClass(metadata.arg.(@key == Tags.ATTR_TYPE).@value);
            var cascadeType:String = StringUtil.trim(metadata.arg.(@key == Tags.ATTR_CASCADE).@value.toString());
            var lazy:Boolean = StringUtils.parseBoolean(metadata.arg.(@key == Tags.ATTR_LAZY).@value.toString(), false);
            var constrain:Boolean = StringUtils.parseBoolean(metadata.arg.(@key == Tags.ATTR_CONSTRAIN).@value.toString(), true);
            var indexed:Boolean = StringUtils.parseBoolean(metadata.arg.(@key == Tags.ATTR_INDEXED).@value.toString(), false);
            var indexColumn:String = StringUtil.trim(metadata.arg.(@key == Tags.ATTR_INDEX_COLUMN).@value.toString());
            var indexProperty:String = null;

            var cn:String = getClassName(type);
            var associationTable:String = c_n + "_" + Inflector.pluralize(StringUtils.underscore(cn).toLowerCase());

            if (indexed && (indexColumn == null || indexColumn.length == 0))
            {
                indexColumn = c_n + "_idx";
            }
            else
            {
                indexColumn = null;
            }

            if (indexColumn)
            {
                indexProperty = StringUtils.camelCase(indexColumn);
            }

            var associatedEntity:Entity = _entityMap[cn];
            if (associatedEntity == null)
            {
                associatedEntity = getEntity(type, cn);
                deferred.push(type);
            }

            var a:ManyToManyAssociation = new ManyToManyAssociation(
            {
                property        : property,
                associationTable: associationTable,
                associatedEntity: associatedEntity,
                cascadeType     : cascadeType,
                lazy            : lazy,
                constrain       : constrain,
                indexed         : indexed,
                indexColumn     : indexColumn,
                indexProperty   : indexProperty
            });
            associatedEntity.addManyToManyInverseAssociation(a);
            entity.addManyToManyAssociation(a);
            associatedEntity.addDependency(entity);
        }

        private function isEntity(property:String):Boolean
        {
            var singular:String = Inflector.singularize(property);
            for (var key:String in _entityMap)
            {
                if (key == singular)
                    return true;
            }
            return false;
        }

        /**
         * Walk up the identity graph to collect the base identities and
         * paths to them. The tops of the identity graph are expected to
         * be entities with primary keys.
         */
        private function getIdentities(entity:Entity, path:Array=null):Array
        {
            if (path == null)
                path = [];

            var identities:Array = [];
            for each(var key:Key in entity.keys)
            {
                if (key is CompositeKey)
                {
                    identities = identities.concat(getIdentities(CompositeKey(key).associatedEntity, path.concat(key)));
                }
                else
                {
                    var pk:PrimaryKey = PrimaryKey(key);
                    if (path.length == 0)
                    {
                        identities.push(new Identity(
                        {
                            property  : pk.property,
                            column    : pk.column,
                            fkProperty: entity.fkProperty,
                            fkColumn  : entity.fkColumn,
                            strategy  : pk.strategy,
                            path      : []
                        }));
                    }
                    else
                    {
                        identities.push(new Identity(
                        {
                            property  : entity.fkProperty,
                            column    : entity.fkColumn,
                            fkProperty: entity.fkProperty,
                            fkColumn  : entity.fkColumn,
                            strategy  : pk.strategy,
                            path      : path.concat(key)
                        }));
                    }
                }
            }
            return identities;
        }

        private function buildSQLCommands(entity:Entity):void
        {
            var table:String = entity.table;

            var selectCommand:SelectCommand = entity.selectCommand;
            if (selectCommand == null)
            {
                selectCommand = new SelectCommand(_sqlConnection, _schema, table, _debugLevel);
                entity.selectCommand = selectCommand;
            }
            var selectSubtypeCommand:SelectCommand = null;
            if (entity.superEntity)
            {
                selectSubtypeCommand = new SelectCommand(_sqlConnection, _schema, table, _debugLevel);
                for each(identity in entity.identities)
                {
                    selectSubtypeCommand.addJoin(entity.superEntity.table, identity.column, identity.column);
                }
                entity.selectSubtypeCommand = selectSubtypeCommand;
            }
            var selectNestedSetsCommand:SelectCommand = null;
            if (entity.hierarchical)
            {
                selectNestedSetsCommand = new SelectCommand(_sqlConnection, _schema, table, _debugLevel);
                if (entity.isSuperEntity())
                    entity.selectNestedSetTypesCommand = new SelectNestedSetTypesCommand(_sqlConnection, _schema, table, _debugLevel);
            }
            var selectAllCommand:SelectCommand = new SelectCommand(_sqlConnection, _schema, table, _debugLevel);
            var insertCommand:InsertCommand = new InsertCommand(_sqlConnection, _schema, table, _debugLevel);
            var updateCommand:UpdateCommand = new UpdateCommand(_sqlConnection, _schema, table, _prefs.syncSupport, _debugLevel);
            var deleteCommand:DeleteCommand = new DeleteCommand(_sqlConnection, _schema, table, _debugLevel);
            var createSynCommand:CreateSynCommand = new CreateSynCommand(_sqlConnection, _schema, table, _debugLevel);
            var createAsynCommand:CreateAsynCommand = new CreateAsynCommand(_sqlConnection, _schema, table, _debugLevel);
            var markForDeletionCommand:UpdateCommand = new UpdateCommand(_sqlConnection, _schema, table, false, _debugLevel);

            // ************************************************
            // Synchronisation Support Commands

            var selectUpdatedCommand:SelectCommand = null;
            var updateVersionCommand:UpdateCommand = null;
            var selectServerKeyMapCommand:SelectCommand = null;
            var selectKeysCommand:SelectCommand = null;

            var indexCommands:Array = [];
            var indexTableName:String = StringUtils.underscore(entity.tableSingular).toLowerCase();
            var indexName:String;
            var createIndexCommand:CreateIndexCommand;
            var identity:Identity;
            var pk:PrimaryKey = entity.pk;
            var idSQLType:String;

            if (entity.hasCompositeKey())
            {
                indexName = indexTableName + "_key_idx";
                createIndexCommand = new CreateIndexCommand(_sqlConnection, _schema, table, indexName, _debugLevel);
                selectKeysCommand = new SelectCommand(_sqlConnection, _schema, table, _debugLevel);
                for each(identity in entity.identities)
                {
                    selectKeysCommand.addColumn(identity.column);
                    createIndexCommand.addIndex(identity.column);
                }
                selectKeysCommand.addColumn("version");
                indexCommands.push(createIndexCommand);
            }
            else
            {
                selectCommand.addColumn(pk.column, entity.fkProperty);
                selectServerKeyMapCommand = new SelectCommand(_sqlConnection, _schema, table, _debugLevel);
                selectServerKeyMapCommand.addColumn(pk.column);
                selectServerKeyMapCommand.addColumn("server_id");
                selectServerKeyMapCommand.addColumn("version");
                idSQLType = getSQLTypeForID(pk.strategy);
                if (entity.superEntity)
                {
                    insertCommand.addColumn(pk.column, entity.fkProperty);
                    createSynCommand.addColumn(pk.column, idSQLType);
                    createAsynCommand.addColumn(pk.column, idSQLType);
                }
                else
                {
                    createSynCommand.setPrimaryKey(pk.column, pk.strategy);
                    createAsynCommand.setPrimaryKey(pk.column, pk.strategy);
                    if (IDStrategy.UID == pk.strategy)
                        insertCommand.addColumn(pk.column, entity.fkProperty);
                }
                indexName = indexTableName + "_" + pk.column + "_idx";
                createIndexCommand = new CreateIndexCommand(_sqlConnection, _schema, table, indexName, _debugLevel);
                createIndexCommand.addIndex(pk.column);
                indexCommands.push(createIndexCommand);
            }

            if (_prefs.syncSupport)
            {
                selectUpdatedCommand = new SelectCommand(_sqlConnection, _schema, table, _debugLevel);
                selectUpdatedCommand.addSQLCondition("updated_at>:lastSyncDate");
                updateVersionCommand = new UpdateCommand(_sqlConnection, _schema, table, _prefs.syncSupport, _debugLevel);
                insertCommand.addColumn("version", "version");
                updateVersionCommand.addColumn("version", "version");
                createSynCommand.addColumn("version", SQLType.INTEGER);
                createAsynCommand.addColumn("version", SQLType.INTEGER);
                if (!entity.hasCompositeKey())
                {
                    idSQLType = getSQLTypeForID(pk.strategy);
                    insertCommand.addColumn("server_id", "serverId");
                    createSynCommand.addColumn("server_id", idSQLType);
                    createAsynCommand.addColumn("server_id", idSQLType);
                }
            }

            for each(identity in entity.identities)
            {
                selectCommand.addFilter(identity.column, identity.fkProperty);
                updateCommand.addFilter(identity.column, identity.fkProperty);
                deleteCommand.addFilter(identity.column, identity.fkProperty);
                markForDeletionCommand.addFilter(identity.column, identity.fkProperty);
                if (_prefs.syncSupport)
                    updateVersionCommand.addFilter(identity.column, identity.fkProperty);
            }

            for each(var f:Field in entity.fields)
            {
                if (entity.hasCompositeKey() || (pk.property != f.property))
                {
                    selectCommand.addColumn(f.column, f.property);
                    insertCommand.addColumn(f.column, f.property);
                    updateCommand.addColumn(f.column, f.property);
                    createSynCommand.addColumn(f.column, f.type);
                    createAsynCommand.addColumn(f.column, f.type);
                }
            }

            insertCommand.addColumn("created_at", "createdAt");
            insertCommand.addColumn("updated_at", "updatedAt");
            insertCommand.addColumn("marked_for_deletion", "markedForDeletion");
            updateCommand.addColumn("updated_at", "updatedAt");
            createSynCommand.addColumn("created_at", SQLType.DATE);
            createSynCommand.addColumn("updated_at", SQLType.DATE);
            createSynCommand.addColumn("marked_for_deletion", SQLType.BOOLEAN);
            createAsynCommand.addColumn("created_at", SQLType.DATE);
            createAsynCommand.addColumn("updated_at", SQLType.DATE);
            createAsynCommand.addColumn("marked_for_deletion", SQLType.BOOLEAN);
            selectAllCommand.addSQLCondition("marked_for_deletion<>true");
            markForDeletionCommand.addColumn("marked_for_deletion", "markedForDeletion");
            markForDeletionCommand.setParam("markedForDeletion", true);

            if (entity.isSuperEntity())
            {
                selectCommand.addColumn("entity_type", "entityType");
                insertCommand.addColumn("entity_type", "entityType");
                createSynCommand.addColumn("entity_type", SQLType.STRING);
                createAsynCommand.addColumn("entity_type", SQLType.STRING);
            }

            var associatedEntity:Entity;

            for each(var a:Association in entity.manyToOneAssociations)
            {
                associatedEntity = a.associatedEntity;
                indexName = indexTableName + "_" + associatedEntity.tableSingular + "_idx";
                createIndexCommand = new CreateIndexCommand(_sqlConnection, _schema, table, indexName, _debugLevel);

                if (associatedEntity.hasCompositeKey())
                {
                    for each(identity in associatedEntity.identities)
                    {
                        idSQLType = getSQLTypeForID(identity.strategy);
                        selectCommand.addColumn(identity.fkColumn, identity.fkProperty);
                        insertCommand.addColumn(identity.fkColumn, identity.fkProperty);
                        updateCommand.addColumn(identity.fkColumn, identity.fkProperty);
                        if (a.constrain)
                        {
                            createSynCommand.addForeignKey(identity.fkColumn, idSQLType, associatedEntity.table, identity.column);
                            createAsynCommand.addForeignKey(identity.fkColumn, idSQLType, associatedEntity.table, identity.column);
                        }
                        else
                        {
                            createSynCommand.addColumn(identity.fkColumn, idSQLType);
                            createAsynCommand.addColumn(identity.fkColumn, idSQLType);
                        }
                        createIndexCommand.addIndex(identity.fkColumn);
                    }
                }
                else
                {
                    idSQLType = getSQLTypeForID(associatedEntity.pk.strategy);
                    selectCommand.addColumn(a.fkColumn, a.fkProperty);
                    insertCommand.addColumn(a.fkColumn, a.fkProperty);
                    updateCommand.addColumn(a.fkColumn, a.fkProperty);
                    if (a.constrain)
                    {
                        createSynCommand.addForeignKey(a.fkColumn, idSQLType, associatedEntity.table, associatedEntity.pk.column);
                        createAsynCommand.addForeignKey(a.fkColumn, idSQLType, associatedEntity.table, associatedEntity.pk.column);
                    }
                    else
                    {
                        createSynCommand.addColumn(a.fkColumn, idSQLType);
                        createAsynCommand.addColumn(a.fkColumn, idSQLType);
                    }
                    createIndexCommand.addIndex(a.fkColumn);
                }
                indexCommands.push(createIndexCommand);
            }

            for each(var otm:OneToManyAssociation in entity.oneToManyInverseAssociations)
            {
                // entity == otm.associatedEntity
                // table == otm.associatedEntity.table

                // otm.fkColumn may not equal ownerEntity.fkColumn where the
                // Many end of the One-to-many association is called something
                // different than the className_id of the ownerEntity, such as
                // when there are multiple one-to-many associations to the
                // same object with different roles.

                // Currently, I am always naming the FK using the classname_id
                // convention regardless if the id field of the ownerEntity has
                // some other name, unless the name of the many-to-one side is
                // explicitly set.

                var otmDeleteCommand:DeleteCommand = new DeleteCommand(_sqlConnection, _schema, table, _debugLevel);
                var otmUpdateCommand:UpdateCommand = new UpdateCommand(_sqlConnection, _schema, table, _prefs.syncSupport, _debugLevel);
                var ownerEntity:Entity = otm.ownerEntity;

                if (ownerEntity.hasCompositeKey())
                {
                    indexName = indexTableName + "_" + ownerEntity.tableSingular + "_idx";
                    createIndexCommand = new CreateIndexCommand(_sqlConnection, _schema, table, indexName, _debugLevel);
                    for each(identity in ownerEntity.identities)
                    {
                        selectCommand.addColumn(identity.fkColumn, identity.fkProperty);
                        insertCommand.addColumn(identity.fkColumn, identity.fkProperty);
                        updateCommand.addColumn(identity.fkColumn, identity.fkProperty);
                        idSQLType = getSQLTypeForID(identity.strategy);
                        if (otm.constrain)
                        {
                            createSynCommand.addForeignKey(identity.fkColumn, idSQLType, ownerEntity.table, identity.column);
                            createAsynCommand.addForeignKey(identity.fkColumn, idSQLType, ownerEntity.table, identity.column);
                        }
                        else
                        {
                            createSynCommand.addColumn(identity.fkColumn, idSQLType);
                            createAsynCommand.addColumn(identity.fkColumn, idSQLType);
                        }
                        otmDeleteCommand.addFilter(identity.fkColumn, identity.fkProperty);
                        otmUpdateCommand.addFilter(identity.fkColumn, identity.fkProperty);
                        otmUpdateCommand.addColumn(identity.fkColumn, "zero");
                        if (IDStrategy.UID == identity.strategy)
                        {
                            otmUpdateCommand.setParam("zero", null);
                        }
                        else
                        {
                            otmUpdateCommand.setParam("zero", 0);
                        }
                        createIndexCommand.addIndex(identity.fkColumn);
                    }
                    indexCommands.push(createIndexCommand);
                }
                else
                {
                    selectCommand.addColumn(otm.fkColumn, otm.fkProperty);
                    insertCommand.addColumn(otm.fkColumn, otm.fkProperty);
                    updateCommand.addColumn(otm.fkColumn, otm.fkProperty);

                    var constraintTable:String = ownerEntity.table;
                    var constraintColumn:String = ownerEntity.pk.column;
                    idSQLType = getSQLTypeForID(ownerEntity.pk.strategy);
                    if (otm.constrain)
                    {
                        createSynCommand.addForeignKey(otm.fkColumn, idSQLType, constraintTable, constraintColumn);
                        createAsynCommand.addForeignKey(otm.fkColumn, idSQLType, constraintTable, constraintColumn);
                    }
                    else
                    {
                        createSynCommand.addColumn(otm.fkColumn, idSQLType);
                        createAsynCommand.addColumn(otm.fkColumn, idSQLType);
                    }
                    otmDeleteCommand.addFilter(otm.fkColumn, otm.fkProperty);
                    otmUpdateCommand.addFilter(otm.fkColumn, otm.fkProperty);
                    otmUpdateCommand.addColumn(otm.fkColumn, "zero");
                    if (IDStrategy.UID == ownerEntity.pk.strategy)
                    {
                        otmUpdateCommand.setParam("zero", null);
                    }
                    else
                    {
                        otmUpdateCommand.setParam("zero", 0);
                    }

                    indexName = indexTableName + "_" + otm.fkColumn + "_idx";
                    createIndexCommand = new CreateIndexCommand(_sqlConnection, _schema, table, indexName, _debugLevel);
                    createIndexCommand.addIndex(otm.fkColumn);
                    indexCommands.push(createIndexCommand);
                }
                otm.deleteCommand = otmDeleteCommand;
                otm.updateFKAfterDeleteCommand = otmUpdateCommand;

                if (otm.indexed)
                {
                    insertCommand.addColumn(otm.indexColumn, otm.indexProperty);
                    updateCommand.addColumn(otm.indexColumn, otm.indexProperty);
                    createSynCommand.addColumn(otm.indexColumn, SQLType.INTEGER);
                    createAsynCommand.addColumn(otm.indexColumn, SQLType.INTEGER);

                    indexName = indexTableName + "_" + otm.indexColumn;
                    var otmCreateIndexCmd:CreateIndexCommand = new CreateIndexCommand(_sqlConnection, _schema, table, indexName, _debugLevel);
                    otmCreateIndexCmd.addIndex(otm.indexColumn);
                    indexCommands.push(otmCreateIndexCmd);
                }

                if (otm.hierarchical)
                {
                    selectCommand.addColumn("lft", "lft");
                    selectCommand.addColumn("rgt", "rgt");
                    insertCommand.addColumn("lft", "lft");
                    insertCommand.addColumn("rgt", "rgt");
                    updateCommand.addColumn("lft", "lft");
                    updateCommand.addColumn("rgt", "rgt");
                    createSynCommand.addColumn("lft", SQLType.INTEGER);
                    createSynCommand.addColumn("rgt", SQLType.INTEGER);
                    createAsynCommand.addColumn("lft", SQLType.INTEGER);
                    createAsynCommand.addColumn("rgt", SQLType.INTEGER);

                    indexName = indexTableName + "_lft";
                    var nodeCreateIndexCmd:CreateIndexCommand = new CreateIndexCommand(_sqlConnection, _schema, table, indexName, _debugLevel);
                    nodeCreateIndexCmd.addIndex("lft");
                    indexCommands.push(nodeCreateIndexCmd);

                    entity.updateLeftBoundaryCommand = new UpdateNestedSetsLeftBoundaryCommand(_sqlConnection, _schema, table, _debugLevel);
                    entity.updateRightBoundaryCommand = new UpdateNestedSetsRightBoundaryCommand(_sqlConnection, _schema, table, _debugLevel);
                    entity.updateNestedSetsCommand = new UpdateNestedSetsCommand(_sqlConnection, _schema, table, _debugLevel);
                    entity.selectMaxRgtCommand = new SelectMaxRgtCommand(_sqlConnection, _schema, table, _debugLevel);

                    selectNestedSetsCommand.addFilterObject(new SQLCondition(table, "lft>:lft"));
                    selectNestedSetsCommand.addFilterObject(new SQLCondition(table, "rgt<:rgt"));
                    selectNestedSetsCommand.addSort("lft", Sort.ASC, table);
                }
            }

            if (entity.hierarchical)
            {
                selectNestedSetsCommand.mergeColumns(selectCommand.columns);
            }

            selectAllCommand.mergeColumns(selectCommand.columns);
            if (entity.superEntity)
                selectSubtypeCommand.mergeColumns(selectCommand.columns);

            buildOneToManySQLCommands(entity);

            buildManyToManySQLCommands(entity, indexName, indexCommands, createIndexCommand);

            entity.selectAllCommand = selectAllCommand;
            entity.selectNestedSetsCommand = selectNestedSetsCommand;
            entity.insertCommand = insertCommand;
            entity.updateCommand = updateCommand;
            entity.deleteCommand = deleteCommand;
            entity.createSynCommand = createSynCommand;
            entity.createAsynCommand = createAsynCommand;
            entity.selectKeysCommand = selectKeysCommand;
            entity.markForDeletionCommand = markForDeletionCommand;
            entity.selectServerKeyMapCommand = selectServerKeyMapCommand;
            entity.selectUpdatedCommand = selectUpdatedCommand;
            entity.updateVersionCommand = updateVersionCommand;
            entity.indexCommands = indexCommands;
        }

        private function buildOneToManySQLCommands(entity:Entity):void
        {
            for each(var a:OneToManyAssociation in entity.oneToManyAssociations)
            {
                for each(var type:AssociatedType in a.associatedTypes)
                {
                    var associatedEntity:Entity = type.associatedEntity;
                    var selectCommand:SelectCommand = new SelectCommand(_sqlConnection, _schema, associatedEntity.table, _debugLevel);
                    if (associatedEntity.selectCommand)
                    {
                        selectCommand.columns = associatedEntity.selectCommand.columns;
                    }
                    else
                    {
                        associatedEntity.selectCommand = new SelectCommand(_sqlConnection, _schema, associatedEntity.table, _debugLevel);
                        associatedEntity.selectCommand.columns = selectCommand.columns;
                    }
                    selectCommand.addSort(a.indexColumn);
                    if (entity.hasCompositeKey())
                    {
                        for each(var identity:Identity in entity.identities)
                        {
                            selectCommand.addFilter(identity.fkColumn, identity.fkProperty);
                        }
                    }
                    else
                    {
                        selectCommand.addFilter(a.fkColumn, a.fkProperty);
                    }
                    type.selectCommand = selectCommand;
                }
            }
        }

        private function buildManyToManySQLCommands(entity:Entity, indexName:String, indexCommands:Array, createIndexCmd:CreateIndexCommand):void
        {
            for each(var a:ManyToManyAssociation in entity.manyToManyAssociations)
            {
                var associationTable:String = a.associationTable;
                var associatedEntity:Entity = a.associatedEntity;

                var selectManyToManyCommand:SelectCommand = new SelectCommand(_sqlConnection, _schema, associatedEntity.table, _debugLevel);
                if (associatedEntity.selectCommand)
                {
                    // Must reference the same columns object - not just copy data across,
                    // so that future additions to columns will be reflected in both commands
                    selectManyToManyCommand.columns = associatedEntity.selectCommand.columns;
                }
                else
                {
                    associatedEntity.selectCommand = new SelectCommand(_sqlConnection, _schema, associatedEntity.table, _debugLevel);
                    associatedEntity.selectCommand.columns = selectManyToManyCommand.columns;
                }
                var selectManyToManyKeysCommand:SelectCommand = new SelectCommand(_sqlConnection, _schema, associationTable, _debugLevel);
                var insertCommand:InsertCommand = new InsertCommand(_sqlConnection, _schema, associationTable, _debugLevel);
                var deleteCommand:DeleteCommand = new DeleteCommand(_sqlConnection, _schema, associationTable, _debugLevel);
                var createSynCommand:CreateSynCommand = new CreateSynCommand(_sqlConnection, _schema, associationTable, _debugLevel);
                var createAsynCommand:CreateAsynCommand = new CreateAsynCommand(_sqlConnection, _schema, associationTable, _debugLevel);
                var updateCommand:UpdateCommand = null;

                if (a.indexed)
                {
                    selectManyToManyCommand.addSort(a.indexColumn, Sort.ASC, associationTable);
                    insertCommand.addColumn(a.indexColumn, a.indexProperty);
                    createSynCommand.addColumn(a.indexColumn, SQLType.INTEGER);
                    createAsynCommand.addColumn(a.indexColumn, SQLType.INTEGER);
                    updateCommand = new UpdateCommand(_sqlConnection, _schema, associationTable, _prefs.syncSupport, _debugLevel);
                    updateCommand.addColumn(a.indexColumn, a.indexProperty);

                    indexName = Inflector.singularize(associationTable) + "_" + a.indexColumn;
                    var createManyToManyIndexCommand:CreateIndexCommand = new CreateIndexCommand(_sqlConnection, _schema, associationTable, indexName, _debugLevel);
                    createManyToManyIndexCommand.addIndex(a.indexColumn);
                    indexCommands.push(createManyToManyIndexCommand);
                }
                indexName = Inflector.singularize(associationTable) + "_key_idx";
                createIndexCmd = new CreateIndexCommand(_sqlConnection, _schema, associationTable, indexName, _debugLevel);

                var identity:Identity;
                var idSQLType:String;

                for each(identity in associatedEntity.identities)
                {
                    selectManyToManyCommand.addJoin(associationTable, identity.column, identity.fkColumn);
                    insertCommand.addColumn(identity.fkColumn, identity.fkProperty);
                    deleteCommand.addFilter(identity.fkColumn, identity.fkProperty);
                    selectManyToManyKeysCommand.addColumn(identity.fkColumn, identity.fkProperty);
                    idSQLType = getSQLTypeForID(identity.strategy);
                    if (a.constrain)
                    {
                        createSynCommand.addForeignKey(identity.fkColumn, idSQLType, associatedEntity.table, identity.column);
                        createAsynCommand.addForeignKey(identity.fkColumn, idSQLType, associatedEntity.table, identity.column);
                    }
                    else
                    {
                        createSynCommand.addColumn(identity.fkColumn, idSQLType);
                        createAsynCommand.addColumn(identity.fkColumn, idSQLType);
                    }
                    if (a.indexed)
                    {
                        updateCommand.addFilter(identity.fkColumn, identity.fkProperty);
                    }
                    createIndexCmd.addIndex(identity.fkColumn);
                }

                // entity == mtm.ownerEntity
                for each(identity in entity.identities)
                {
                    selectManyToManyCommand.addFilter(identity.fkColumn, identity.fkProperty, associationTable);
                    insertCommand.addColumn(identity.fkColumn, identity.fkProperty);
                    deleteCommand.addFilter(identity.fkColumn, identity.fkProperty);
                    selectManyToManyKeysCommand.addFilter(identity.fkColumn, identity.fkProperty);
                    idSQLType = getSQLTypeForID(identity.strategy);
                    if (a.constrain)
                    {
                        createSynCommand.addForeignKey(identity.fkColumn, idSQLType, entity.table, identity.column);
                        createAsynCommand.addForeignKey(identity.fkColumn, idSQLType, entity.table, identity.column);
                    }
                    else
                    {
                        createSynCommand.addColumn(identity.fkColumn, idSQLType);
                        createAsynCommand.addColumn(identity.fkColumn, idSQLType);
                    }
                    if (a.indexed)
                    {
                        updateCommand.addFilter(identity.fkColumn, identity.fkProperty);
                    }
                    createIndexCmd.addIndex(identity.fkColumn);
                }
                indexCommands.push(createIndexCmd);

                a.selectCommand = selectManyToManyCommand;
                a.selectManyToManyKeysCommand = selectManyToManyKeysCommand;
                a.insertCommand = insertCommand;
                a.updateCommand = updateCommand;
                a.deleteCommand = deleteCommand;
                a.createSynCommand = createSynCommand;
                a.createAsynCommand = createAsynCommand;
            }
        }

        private function getClass(asType:String):Class
        {
            return getDefinitionByName(asType) as Class;
        }

        private function getClassName(cls:Class):String
        {
            var qname:String = getQualifiedClassName(cls);
            return qname.substring(qname.lastIndexOf(":") + 1);
        }

        private function getClassNameLower(cls:Class):String
        {
            var cn:String = getClassName(cls);
            return cn.substr(0,1).toLowerCase() + cn.substr(1);
        }

        private function getSQLType(asType:String):String
        {
            switch (asType)
            {
                case "int" || "uint":
                    return SQLType.INTEGER;
                    break;
                case "Number":
                    return SQLType.REAL;
                    break;
                case "Date":
                    return SQLType.DATE;
                    break;
                case "Boolean":
                    return SQLType.BOOLEAN;
                    break;
                default:
                    return SQLType.TEXT;
            }
        }

        private function getIDStrategy(asType:String):String
        {
            switch (asType)
            {
                case "String":
                    return IDStrategy.UID;
                    break;
                default:
                    return IDStrategy.AUTO_INCREMENT;
            }
        }

        private function getSQLTypeForID(idStrategy:String):String
        {
            switch (idStrategy)
            {
                case IDStrategy.UID:
                    return SQLType.STRING;
                    break;
                default:
                    return SQLType.INTEGER;
            }
        }

        private function usingCamelCaseNames():Boolean
        {
            return (NamingStrategy.CAMEL_CASE_NAMES == _prefs.namingStrategy);
        }

        private function getEntityFromType(asType:String):Entity
        {
            return getEntity(getClass(asType));
        }

        private function getEntity(cls:Class, cn:String=null, c_n:String=null):Entity
        {
            if (cn == null)
                cn = getClassName(cls);
            var entity:Entity = _entityMap[cn];
            if (entity)
            {
                if (entity.initialisationComplete)
                    return entity;
            }
            else
            {
                entity = new Entity();
                entity.cls = cls;
                entity.className = cn;
                entity.name = cn;
                _entityMap[cn] = entity;
                var fkProperty:String = StringUtils.startLowerCase(cn) + "Id";
                if (usingCamelCaseNames())
                {
                    entity.fkColumn = fkProperty;
                }
                else
                {
                    if (c_n == null)
                        c_n = StringUtils.underscore(cn).toLowerCase();
                    entity.fkColumn = c_n + "_id";
                }
                entity.fkProperty = fkProperty;
            }
            return entity;
        }




        /**
         * Sandbox feature: requires persistence of metadata such as in the
         * database. TODO remove constructors with arguments from metamodel
         * objects and add annotations.
         *
         * The annotations on typed objects serve as persistent storage of
         * metadata that is read at the start of each EntityManager session.
         */
        public function loadMetadataForDynamicObject(obj:Object, name:String):Entity
        {
            deferred.length = 0;
            return loadMetadataForObject(obj, name, name);
        }

        private function getEntityForObject(cls:Class, root:String, name:String):Entity
        {
            var entity:Entity = _entityMap[name];
            if (entity == null)
            {
                entity = new Entity();
                entity.cls = cls;
                entity.className = getClassName(cls);
                entity.root = root;
                entity.table = name;
                entity.name = name;
                _entityMap[name] = entity;
                var tableSingular:String = Inflector.singularize(StringUtils.camelCase(name));
                var fkProperty:String = StringUtils.startLowerCase(tableSingular) + "Id";
                entity.fkProperty = fkProperty;
                if (usingCamelCaseNames())
                {
                    entity.fkColumn = fkProperty;
                }
                else
                {
                    tableSingular = Inflector.singularize(StringUtils.underscore(name).toLowerCase());
                    entity.fkColumn = tableSingular + "_id";
                }
                entity.tableSingular = tableSingular;
            }
            return entity;
        }

        private function loadMetadataForObject(obj:Object, name:String, root:String):Entity
        {
            var c:Class = Class(getDefinitionByName(getQualifiedClassName(obj)));
            var entity:Entity = getEntityForObject(c, root, name);
            for (var property:String in obj)
            {
                var column:String = usingCamelCaseNames() ?
                    property : StringUtils.underscore(property);

                var associatedEntity:Entity;
                var value:Object = obj[property];
                if (value)
                {
                    var cls:Class = Class(getDefinitionByName(getQualifiedClassName(value)));
                    var cn:String = getClassName(cls);
                    if ("Object" == cn)
                    {
                        associatedEntity = loadMetadataForObject(value, property, root);
                        entity.addManyToOneAssociation(new Association(
                        {
                            property        : property,
                            associatedEntity: associatedEntity,
                            fkColumn        : associatedEntity.fkColumn,
                            fkProperty      : associatedEntity.fkProperty
                        }));
                    }

                    else if ((value is Array || value is ArrayCollection) && (value.length > 0))
                    {
                        for each(var item:Object in value)
                        {
                            if (item) // only need one sample object
                                break;
                        }
                        var itemClass:Class = Class(getDefinitionByName(getQualifiedClassName(item)));
                        var itemCN:String = getClassName(itemClass);
                        if ("Object" == itemCN)
                        {
                            associatedEntity = _entityMap[property];
                            if (associatedEntity == null)
                            {
                                associatedEntity = getEntityForObject(itemClass, root, property);
                                deferred.push({ type: item, name: property });
                            }
                        }
                        else
                        {
                            associatedEntity = _entityMap[itemCN];
                            if (associatedEntity == null)
                            {
                                associatedEntity = getEntity(itemClass, itemCN);
                                deferred.push({ type: itemClass });
                            }
                        }
                        var associatedTypes:Array = [];
                        var type:AssociatedType = new AssociatedType();
                        type.associatedEntity = associatedEntity;
                        associatedTypes.push(type);
                        var a:OneToManyAssociation = new OneToManyAssociation(
                        {
                            property       : property,
                            associatedTypes: associatedTypes,
                            fkColumn       : entity.fkColumn,
                            fkProperty     : entity.fkProperty
                        });
                        associatedEntity.addOneToManyInverseAssociation(a);
                        entity.addOneToManyAssociation(a); // also sets the ownerEntity as entity
                    }

                    else
                    {
                        entity.addField(new Field(
                        {
                            property: property,
                            column  : column,
                            type    : getSQLType(cn)
                        }));
                    }
                }
            }

            var key:String = "__id";
            obj[key] = 0;
            entity.addKey(new PrimaryKey(
            {
                property: key,
                column  : entity.fkColumn,
                strategy: IDStrategy.AUTO_INCREMENT
            }));
            entity.identities = getIdentities(entity);
            buildSQLCommands(entity);
            entity.createSynCommand.execute();
            entity.initialisationComplete = true;

            while (deferred.length > 0)
            {
                var def:Object = deferred.pop();
                if (def.name)
                {
                    loadMetadataForObject(def.type, def.name, root);
                }
                else
                {
                    loadMetadataForClass(def.type);
                }
            }

            return entity;
        }

    }
}