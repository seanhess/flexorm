package nz.co.codec.flexorm
{
    import flash.data.SQLConnection;
    import flash.utils.describeType;
    import flash.utils.getDefinitionByName;
    import flash.utils.getQualifiedClassName;

    import mx.collections.ArrayCollection;
    import mx.collections.IList;
    import mx.utils.StringUtil;

    import nz.co.codec.flexorm.command.CreateCommand;
    import nz.co.codec.flexorm.command.CreateCommandAsync;
    import nz.co.codec.flexorm.command.CreateIndexCommand;
    import nz.co.codec.flexorm.command.DeleteCommand;
    import nz.co.codec.flexorm.command.FindAllCommand;
    import nz.co.codec.flexorm.command.InsertCommand;
    import nz.co.codec.flexorm.command.MarkForDeletionCommand;
    import nz.co.codec.flexorm.command.SelectCommand;
    import nz.co.codec.flexorm.command.SelectFkMapCommand;
    import nz.co.codec.flexorm.command.SelectIdMapCommand;
    import nz.co.codec.flexorm.command.SelectManyToManyCommand;
    import nz.co.codec.flexorm.command.SelectManyToManyIndicesCommand;
    import nz.co.codec.flexorm.command.SelectUnsynchronisedCommand;
    import nz.co.codec.flexorm.command.UpdateCommand;
    import nz.co.codec.flexorm.metamodel.Association;
    import nz.co.codec.flexorm.metamodel.CompositeIdentity;
    import nz.co.codec.flexorm.metamodel.Entity;
    import nz.co.codec.flexorm.metamodel.Field;
    import nz.co.codec.flexorm.metamodel.IIdentity;
    import nz.co.codec.flexorm.metamodel.Key;
    import nz.co.codec.flexorm.metamodel.ManyToManyAssociation;
    import nz.co.codec.flexorm.metamodel.OneToManyAssociation;
    import nz.co.codec.flexorm.metamodel.PrimaryIdentity;
    import nz.co.codec.flexorm.util.Inflector;
    import nz.co.codec.flexorm.util.StringUtils;

    public class EntityIntrospector
    {
        private var _map:Object;

        private var _sqlConnection:SQLConnection;

        private var _namingStrategy:String;

        private var _syncSupport:Boolean;

        private var _deferred:Array;

        private var _debugLevel:int;

        private var appDataTableCreated:Boolean = false;

        public function EntityIntrospector(
            map:Object,
            sqlConnection:SQLConnection,
            namingStrategy:String="underscore",
            syncSupport:Boolean=false)
        {
            _map = map;
            _sqlConnection = sqlConnection;
            _namingStrategy = namingStrategy;
            _syncSupport = syncSupport;
            _deferred = [];
            _debugLevel = 0;
        }

        public function set debugLevel(value:int):void
        {
            _debugLevel = value;
        }

        public function loadMetadata(c:Class, table:String=null, executor:IExecutor=null):Entity
        {
            var entity:Entity = loadMetadataForClass(c, table);

            var entities:Array = [];
            entities.push(entity);
            while (_deferred.length > 0)
            {
                var def:Object = _deferred.pop();
                entities.push(loadMetadataForClass(def.type, def.table));
            }

            populateKeys(entities);

            buildSQL(entities);

            if (executor)
            {
                createTablesAsync(sequenceEntitiesForTableCreation(entities), executor);
            }
            else
            {
                createTables(sequenceEntitiesForTableCreation(entities));
            }

            return entity;
        }

        private function populateKeys(entities:Array):void
        {
            for each(var entity:Entity in entities)
            {
                entity.keys = getKeys(entity);
            }
        }

        private function buildSQL(entities:Array):void
        {
            for each(var entity:Entity in entities)
            {
                buildSQLCommands(entity);
            }
        }

        private function createTablesAsync(createSequence:Array, executor:IExecutor):void
        {
            var associationTableCreateCommands:Array = [];
            for each(var entity:Entity in createSequence)
            {
                for each(var a:ManyToManyAssociation in entity.manyToManyAssociations)
                {
                    associationTableCreateCommands.push(a.createCommandAsync);
                }
                executor.addCommand(entity.createCommandAsync);
            }

            // create association tables last
            for each(var command:CreateCommandAsync in associationTableCreateCommands)
            {
                executor.addCommand(command);
            }

            if (_syncSupport && !appDataTableCreated)
                createAppDataTableAsync(executor); // for synchronisation
        }

        private function createTables(createSequence:Array):void
        {
            var associationTableCreateCommands:Array = [];
            var entity:Entity;
            for each(entity in createSequence)
            {
                for each(var a:ManyToManyAssociation in entity.manyToManyAssociations)
                {
                    associationTableCreateCommands.push(a.createCommand);
                }
                entity.createCommand.execute();
            }

            // create association tables last
            for each(var command:CreateCommand in associationTableCreateCommands)
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

            if (_syncSupport && !appDataTableCreated)
                createAppDataTable(); // for synchronisation
        }

        private function createAppDataTableAsync(executor:IExecutor):void
        {
            var createCommandAsync:CreateCommandAsync = new CreateCommandAsync("app_data", _sqlConnection, _debugLevel);
            createCommandAsync.addColumn("entity", SQLType.STRING);
            createCommandAsync.addColumn("last_synchronised_at", SQLType.DATE);
            executor.addCommand(createCommandAsync);
            appDataTableCreated = true;
        }

        private function createAppDataTable():void
        {
            var createCommand:CreateCommand = new CreateCommand("app_data", _sqlConnection, _debugLevel);
            createCommand.addColumn("entity", SQLType.STRING);
            createCommand.addColumn("last_synchronised_at", SQLType.DATE);
            createCommand.execute();
            appDataTableCreated = true;
        }

        /**
         * Sequence entities so that foreign key constraints are not violated
         * as tables are created.
         */
        private function sequenceEntitiesForTableCreation(entities:Array):Array
        {
            var createSequence:Array = [].concat(entities);
            for each(var entity:Entity in entities)
            {
                var i:int = createSequence.indexOf(entity);
                var k:int = 0;
                for each(var e:Entity in entity.dependencies)
                {
                    var j:int = createSequence.indexOf(e) + 1;
                    k = (j > k)? j : k;
                }
                if (k != i)
                {
                    createSequence.splice(k, 0, entity);
                    if (k < i)
                    {
                        createSequence.splice(i + 1, 1);
                    }
                    else
                    {
                        createSequence.splice(i, 1);
                    }
                }
            }
            return createSequence;
        }

        private function loadMetadataForClass(c:Class, table:String):Entity
        {
            var xml:XML = describeType(new c());
            var tableName:String = StringUtil.trim(xml.metadata.(@name == Tags.ELEM_TABLE).arg.(@key == Tags.ATTR_NAME).@value);
            if (tableName && tableName.length > 0)
            {
                table = tableName;
            }
            var cn:String = getClassName(c);
            var entity:Entity = _map[cn];
            if (entity)
            {
                if (entity.initialisationComplete)
                    return entity;
            }
            else
            {
                entity = new Entity(c, _namingStrategy, table);
                _map[cn] = entity;
            }
            var qname:String = getQualifiedClassName(c);
            var j:int = qname.lastIndexOf(":");
            var pkg:String = (j > 0)? qname.substring(0, j - 1) : null;

            var superType:String = xml.extendsClass[0].@type.toString();
            j = superType.lastIndexOf(":");
            var superPkg:String = (j > 0)? superType.substring(0, j - 1) : null;

            // if superType is of the same package as the persistent entity
            // and is not the Object base class
            if (( pkg && superType.match(pkg)) ||
                (!pkg && !superPkg && superType != "Object"))
            {
                var superClass:Class = getClass(superType);
                var superCN:String = getClassName(superClass);
                var superEntity:Entity = _map[superCN];
                if (superEntity == null)
                {
                    superEntity = new Entity(superClass, _namingStrategy);
                    _map[superCN] = superEntity;
                    _deferred.push({ type: superClass, table: null });
                }
                entity.superEntity = superEntity;
                entity.addDependency(superEntity);
            }

            var candidateId:PrimaryIdentity = null;
            var gotId:Boolean = false;

            var variables:XMLList = xml.accessor;
            for each(var v:Object in variables)
            {
                // skip properties of superclass
                var declaredBy:String = v.@declaredBy.toString();
                if (declaredBy.search(new RegExp(entity.className, "i")) == -1)
                    continue;

                var typeQName:String = getQualifiedClassName(getClass(v.@type));
                j = typeQName.lastIndexOf(":");
                var typePkg:String = (j > 0)? typeQName.substring(0, j - 1) : null;
                var type:Class = getClass(v.@type);      // associated object class
                var typeCN:String = getClassName(type);  // class name of associated object
                var property:String = v.@name.toString();
                var column:String;
                var fkColumn:String;
                var fkProperty:String;
                var associatedEntity:Entity;
                var cascadeType:String;
                var lazy:Boolean;
                var constrain:Boolean;
                var inverse:Boolean;
                var indexed:Boolean;
                var indexColumn:String;
                var indexProperty:String;
                var metadata:XMLList;
                var otm:OneToManyAssociation;

                if (v.metadata.(@name ==Tags.ELEM_COLUMN).length() > 0)
                {
                    column = v.metadata.(@name == Tags.ELEM_COLUMN).arg.(@key == Tags.ATTR_NAME).@value.toString();
                    entity.addField(new Field({
                        property: property,
                        column: column,
                        type: getSQLType(v.@type)
                    }));
                }

                else if (v.metadata.(@name == Tags.ELEM_MANY_TO_ONE).length() > 0)
                {
                    metadata = v.metadata.(@name == Tags.ELEM_MANY_TO_ONE);
                    column = metadata.arg.(@key == Tags.ATTR_NAME).@value.toString();
                    cascadeType = metadata.arg.(@key == Tags.ATTR_CASCADE).@value;
                    inverse = StringUtils.parseBoolean(metadata.arg.(@key == Tags.ATTR_INVERSE).@value.toString(), false);
                    constrain = StringUtils.parseBoolean(metadata.arg.(@key == Tags.ATTR_CONSTRAIN).@value.toString(), true);
                    associatedEntity = _map[typeCN];
                    if (associatedEntity == null)
                    {
                        associatedEntity = new Entity(type, _namingStrategy);
                        _map[typeCN] = associatedEntity;
                        _deferred.push({ type: type, table: null });
                    }

                    if (v.metadata.(@name == Tags.ELEM_ID).length() > 0)
                    {
                        entity.addIdentity(new CompositeIdentity({
                            property: property,
                            associatedEntity: associatedEntity
                        }));
                        gotId = true;
                        cascadeType = CascadeType.NONE;
                    }

                    entity.addManyToOneAssociation(new Association({
                        property: property,
                        associatedEntity: associatedEntity,
                        cascadeType: cascadeType,
                        inverse: inverse,
                        constrain: constrain
                    }));
                    entity.addDependency(associatedEntity);
                }

                else if (v.metadata.(@name == Tags.ELEM_ONE_TO_MANY).length() > 0)
                {
                    metadata = v.metadata.(@name == Tags.ELEM_ONE_TO_MANY);
                    type = getClass(metadata.arg.(@key == Tags.ATTR_TYPE).@value);
                    typeCN = getClassName(type);
                    cascadeType = metadata.arg.(@key == Tags.ATTR_CASCADE).@value;
                    lazy = StringUtils.parseBoolean(metadata.arg.(@key == Tags.ATTR_LAZY).@value.toString(), false);
                    inverse = StringUtils.parseBoolean(metadata.arg.(@key == Tags.ATTR_INVERSE).@value.toString(), false);
                    constrain = StringUtils.parseBoolean(metadata.arg.(@key == Tags.ATTR_CONSTRAIN).@value.toString(), true);
                    fkColumn = StringUtil.trim(metadata.arg.(@key == Tags.ATTR_FK_COLUMN).@value);
                    if (fkColumn == null || fkColumn.length == 0)
                    {
                        fkColumn = entity.fkColumn;
                    }
                    fkProperty = StringUtils.camelCase(fkColumn);
                    indexed = StringUtils.parseBoolean(metadata.arg.(@key == Tags.ATTR_INDEXED).@value.toString(), false);
                    indexColumn = StringUtil.trim(metadata.arg.(@key == Tags.ATTR_INDEX_COLUMN).@value);
                    if (indexed && (indexColumn == null || indexColumn.length == 0))
                    {
                        indexColumn = StringUtils.underscore(entity.className).toLowerCase() + "_idx";
                    }
                    else
                    {
                        indexColumn = null;
                    }
                    if (indexColumn == null)
                    {
                        indexProperty = null;
                    }
                    else
                    {
                        indexProperty = StringUtils.camelCase(indexColumn);
                    }
                    associatedEntity = _map[typeCN];
                    if (associatedEntity == null)
                    {
                        associatedEntity = new Entity(type, _namingStrategy);
                        _map[typeCN] = associatedEntity;
                        _deferred.push({ type: type, table: null });
                    }

                    otm = new OneToManyAssociation({
                        property: property,
                        associatedEntity: associatedEntity,
                        cascadeType: cascadeType,
                        lazy: lazy,
                        inverse: inverse,
                        constrain: constrain,
                        fkColumn: fkColumn,
                        fkProperty: fkProperty,
                        indexed: indexed,
                        indexColumn: indexColumn,
                        indexProperty: indexProperty
                    });
                    associatedEntity.addOneToManyInverseAssociation(otm);
                    entity.addOneToManyAssociation(otm); // also sets the ownerEntity as entity
                    associatedEntity.addDependency(entity);
                }

                else if (v.metadata.(@name == Tags.ELEM_MANY_TO_MANY).length() > 0)
                {
                    metadata = v.metadata.(@name == Tags.ELEM_MANY_TO_MANY);
                    cascadeType = metadata.arg.(@key == Tags.ATTR_CASCADE).@value;
                    lazy = StringUtils.parseBoolean(metadata.arg.(@key == Tags.ATTR_LAZY).@value.toString(), false);
                    constrain = StringUtils.parseBoolean(metadata.arg.(@key == Tags.ATTR_CONSTRAIN).@value.toString(), true);
                    type = getClass(metadata.arg.(@key == Tags.ATTR_TYPE).@value);
                    typeCN = getClassName(type);
                    var associationTable:String = entity.className.toLowerCase() + "_" +
                            Inflector.pluralize(getClassName(type)).toLowerCase();
                    indexed = StringUtils.parseBoolean(metadata.arg.(@key == Tags.ATTR_INDEXED).@value.toString(), false);
                    indexColumn = StringUtil.trim(metadata.arg.(@key == Tags.ATTR_INDEX_COLUMN).@value);
                    if (indexed && (indexColumn == null || indexColumn.length == 0))
                    {
                        indexColumn = StringUtils.underscore(entity.className).toLowerCase() + "_idx";
                    }
                    else
                    {
                        indexColumn = null;
                    }
                    if (indexColumn == null)
                    {
                        indexProperty = null;
                    }
                    else
                    {
                        indexProperty = StringUtils.camelCase(indexColumn);
                    }
                    associatedEntity = _map[typeCN];
                    if (associatedEntity == null)
                    {
                        associatedEntity = new Entity(type, _namingStrategy);
                        _map[typeCN] = associatedEntity;
                        _deferred.push({ type: type, table: null });
                    }
                    var mtmAssociation:ManyToManyAssociation = new ManyToManyAssociation({
                        property: property,
                        associationTable: associationTable,
                        associatedEntity: associatedEntity,
                        cascadeType: cascadeType,
                        lazy: lazy,
                        constrain: constrain,
                        indexed: indexed,
                        indexColumn: indexColumn,
                        indexProperty: indexProperty
                    });
                    associatedEntity.addManyToManyInverseAssociation(mtmAssociation);
                    entity.addManyToManyAssociation(mtmAssociation);
                    associatedEntity.addDependency(entity);
                }

                else if (v.metadata.(@name == Tags.ELEM_TRANSIENT).length() > 0)
                {
                    // skip
                }

                // The property has no annotation ----------------------------

                // if type is in the same package as c
                else if (typePkg == pkg) // then infer many-to-one association
                {
                    associatedEntity = _map[typeCN];
                    if (associatedEntity == null)
                    {
                        associatedEntity = new Entity(type, _namingStrategy);
                        _map[typeCN] = associatedEntity;
                        _deferred.push({ type: type, table: null });
                    }

                    entity.addManyToOneAssociation(new Association({
                        property: property,
                        associatedEntity: associatedEntity
                    }));
                    entity.addDependency(associatedEntity);
                }

                // if type is a list and has a property name that matches
                // another entity (depends on the metadata for that entity
                // having being loaded already)
                else if ((type is IList) && guessOneToMany(property))
                {
                    // then infer one-to-many association
                    fkColumn = entity.fkColumn;
                    fkProperty = StringUtils.camelCase(fkColumn);
                    associatedEntity = _map[typeCN];
                    if (associatedEntity == null)
                    {
                        associatedEntity = new Entity(type, _namingStrategy);
                        _map[typeCN] = associatedEntity;
                        _deferred.push({ type: type, table: null });
                    }

                    otm = new OneToManyAssociation({
                        property: property,
                        associatedEntity: associatedEntity,
                        fkColumn: fkColumn,
                        fkProperty: fkProperty
                    });
                    associatedEntity.addOneToManyInverseAssociation(otm);
                    entity.addOneToManyAssociation(otm); // also sets the ownerEntity as entity
                    associatedEntity.addDependency(entity);
                }

                else
                {
                    if (_namingStrategy == NamingStrategy.CAMEL_CASE_NAMES)
                    {
                        column = property;
                    }
                    else
                    {
                        column = StringUtils.underscore(property);
                    }
                    entity.addField(new Field({
                        property: property,
                        column: column,
                        type: getSQLType(v.@type)
                    }));

                    if (candidateId == null &&
                        property.toLowerCase().indexOf("id", property.length - 2) > -1)
                    {
                        candidateId = new PrimaryIdentity({
                            property: property,
                            column: column
                        });
                    }
                }

                if (!gotId && v.metadata.(@name == Tags.ELEM_ID).length() > 0)
                {
                    if (getSQLType(v.@type) != SQLType.INTEGER)
                    {
                        throw new Error("Only int IDs are supported");
                    }
                    entity.addIdentity(new PrimaryIdentity({
                        property: property,
                        column: column
                    }));
                    gotId = true;
                }
            }

            if (!gotId)
            {
                if (candidateId == null)
                {
                    throw new Error("No ID specified for '" + entity.className + "'");
                }
                else
                {
                    entity.addIdentity(candidateId);
                }
            }

            entity.initialisationComplete = true;
            return entity;
        }

        private function guessOneToMany(property:String):Boolean
        {
            var singular:String = Inflector.singularize(property);
            for (var classname:String in _map)
            {
                if (singular == classname)
                    return true;
            }
            return false;
        }

        /**
         * Walk up the identity graph to collect the base identities and
         * paths to them. The tops of the identity graph are expected to
         * be entities with primary keys.
         */
        private function getKeys(entity:Entity, idpath:Array=null):Array
        {
            if (idpath == null)
                idpath = [];

            var keys:Array = [];
            for each(var identity:IIdentity in entity.identities)
            {
                if (identity is CompositeIdentity)
                {
                    keys = keys.concat(getKeys(CompositeIdentity(identity).associatedEntity, idpath.concat(identity)));
                }
                else
                {
                    var pk:PrimaryIdentity = PrimaryIdentity(identity);
                    if (idpath.length == 0)
                    {
                        keys.push(new Key({
                            property: pk.property,
                            column: pk.column,
                            fkProperty: entity.fkProperty,
                            fkColumn: entity.fkColumn
                        }));
                    }
                    else
                    {
                        keys.push(new Key({
                            property: entity.fkProperty,
                            column: entity.fkColumn,
                            idpath: idpath.concat(identity),
                            fkProperty: entity.fkProperty,
                            fkColumn: entity.fkColumn
                        }));
                    }
                }
            }
            return keys;
        }

        private function buildSQLCommands(entity:Entity):void
        {
            var table:String = entity.table;
            var pk:PrimaryIdentity = entity.pk;
            var key:Key;

            var findAllCommand:FindAllCommand = new FindAllCommand(table, _sqlConnection);
            var selectCommand:SelectCommand = new SelectCommand(table, _sqlConnection, _debugLevel);
            var insertCommand:InsertCommand = new InsertCommand(table, _sqlConnection, _debugLevel);
            var updateCommand:UpdateCommand = new UpdateCommand(table, _sqlConnection, _debugLevel);
            var deleteCommand:DeleteCommand = new DeleteCommand(table, _sqlConnection, _debugLevel);
            var createCommand:CreateCommand = new CreateCommand(table, _sqlConnection, _debugLevel);
            var createCommandAsync:CreateCommandAsync = new CreateCommandAsync(table, _sqlConnection, _debugLevel);
            var markForDeletionCommand:MarkForDeletionCommand = new MarkForDeletionCommand(table, _sqlConnection, _debugLevel);
            var indexCommands:Array = [];
            var indexTableName:String = entity.tableSingular;
            var indexName:String;

            var selectUnsynchronisedCommand:SelectUnsynchronisedCommand = null;
            if (_syncSupport)
            {
                selectUnsynchronisedCommand = new SelectUnsynchronisedCommand(table, _sqlConnection, _debugLevel);
            }

            var selectIdMapCommand:SelectIdMapCommand = null;
            var selectFkMapCommand:SelectFkMapCommand = null;
            if (entity.hasCompositeKey())
            {
                indexName = indexTableName + "_key_idx";
                var compositeKeyIndexCommand:CreateIndexCommand = new CreateIndexCommand(table, indexName, _sqlConnection, _debugLevel);
                selectFkMapCommand = new SelectFkMapCommand(table, _sqlConnection, _debugLevel);
                for each(key in entity.keys)
                {
                    selectFkMapCommand.addIdColumn(key.column);
                    compositeKeyIndexCommand.addIndexColumn(key.column);
                }
                indexCommands.push(compositeKeyIndexCommand);
            }
            else
            {
                selectIdMapCommand = new SelectIdMapCommand(table, pk.column, _sqlConnection, _debugLevel);
                if (entity.superEntity)
                {
                    insertCommand.addColumn(pk.column, pk.property);
                    createCommand.addColumn(pk.column, SQLType.INTEGER);
                    createCommandAsync.addColumn(pk.column, SQLType.INTEGER);
                }
                else
                {
                    createCommand.setPk(pk.column);
                    createCommandAsync.setPk(pk.column);
                }
                indexName = indexTableName + "_" + pk.column + "_idx";
                var pkIndexCommand:CreateIndexCommand = new CreateIndexCommand(table, indexName, _sqlConnection, _debugLevel);
                pkIndexCommand.addIndexColumn(pk.column);
                indexCommands.push(pkIndexCommand);
            }

            for each(key in entity.keys)
            {
                selectCommand.addFilter(key.column, key.property);
                updateCommand.addFilter(key.column, key.property);
                deleteCommand.addFilter(key.column, key.property);
                markForDeletionCommand.addFilter(key.column, key.property);
            }

            for each(var f:Field in entity.fields)
            {
                if (pk == null || (f.property != pk.property))
                {
                    insertCommand.addColumn(f.column, f.property);
                    updateCommand.addColumn(f.column, f.property);
                    createCommand.addColumn(f.column, f.type);
                    createCommandAsync.addColumn(f.column, f.type);
                }
            }

            insertCommand.addColumn("created_at", "createdAt");
            insertCommand.addColumn("updated_at", "updatedAt");
            updateCommand.addColumn("updated_at", "updatedAt");
            createCommand.addColumn("created_at", SQLType.DATE);
            createCommand.addColumn("updated_at", SQLType.DATE);
            createCommandAsync.addColumn("created_at", SQLType.DATE);
            createCommandAsync.addColumn("updated_at", SQLType.DATE);

            insertCommand.addColumn("marked_for_deletion", "markedForDeletion");
            createCommand.addColumn("marked_for_deletion", SQLType.BOOLEAN);
            createCommandAsync.addColumn("marked_for_deletion", SQLType.BOOLEAN);

            if (_syncSupport && !entity.hasCompositeKey())
            {
                insertCommand.addColumn("server_id", "serverId");
                createCommand.addColumn("server_id", SQLType.INTEGER);
                createCommandAsync.addColumn("server_id", SQLType.INTEGER);
            }

            var column:Object;
            var fkIndexCommand:CreateIndexCommand;

            for each(var a:Association in entity.manyToOneAssociations)
            {
                indexName = indexTableName + "_" + a.associatedEntity.tableSingular + "_idx";
                fkIndexCommand = new CreateIndexCommand(table, indexName, _sqlConnection, _debugLevel);
                for each(key in a.associatedEntity.keys)
                {
                    insertCommand.addColumn(key.fkColumn, key.fkProperty);
                    updateCommand.addColumn(key.fkColumn, key.fkProperty);
                    if (a.constrain)
                    {
                        createCommand.addFkColumn(key.fkColumn, SQLType.INTEGER, a.associatedEntity.table, key.column);
                        createCommandAsync.addFkColumn(key.fkColumn, SQLType.INTEGER, a.associatedEntity.table, key.column);
                    }
                    else
                    {
                        createCommand.addColumn(key.fkColumn, SQLType.INTEGER);
                        createCommandAsync.addColumn(key.fkColumn, SQLType.INTEGER);
                    }
                    fkIndexCommand.addIndexColumn(key.fkColumn);
                }
                indexCommands.push(fkIndexCommand);
            }

            var otm:OneToManyAssociation;
            for each(otm in entity.oneToManyAssociations)
            {
                var otmSelectCommand:SelectCommand = new SelectCommand(otm.associatedEntity.table, _sqlConnection, _debugLevel, otm.indexColumn);
                if (entity.hasCompositeKey())
                {
                    for each(key in entity.keys)
                    {
                        otmSelectCommand.addFilter(key.fkColumn, key.fkProperty);
                    }
                }
                else
                {
                    otmSelectCommand.addFilter(otm.fkColumn, otm.fkProperty);
                }
                otm.selectCommand = otmSelectCommand;
            }

            for each(otm in entity.oneToManyInverseAssociations)
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

                var otmDeleteCommand:DeleteCommand = new DeleteCommand(table, _sqlConnection, _debugLevel);

                var ownerEntity:Entity = otm.ownerEntity;
                if (ownerEntity.hasCompositeKey())
                {
                    indexName = indexTableName + "_" + ownerEntity.tableSingular + "_idx";
                    fkIndexCommand = new CreateIndexCommand(table, indexName, _sqlConnection, _debugLevel);
                    for each(key in ownerEntity.keys)
                    {
                        insertCommand.addColumn(key.fkColumn, key.fkProperty);
                        updateCommand.addColumn(key.fkColumn, key.fkProperty);

                        if (otm.constrain)
                        {
                            createCommand.addFkColumn(key.fkColumn, SQLType.INTEGER, ownerEntity.table, key.column);
                            createCommandAsync.addFkColumn(key.fkColumn, SQLType.INTEGER, ownerEntity.table, key.column);
                        }
                        else
                        {
                            createCommand.addColumn(key.fkColumn, SQLType.INTEGER);
                            createCommandAsync.addColumn(key.fkColumn, SQLType.INTEGER);
                        }

                        otmDeleteCommand.addFilter(key.fkColumn, key.fkProperty);
                        fkIndexCommand.addIndexColumn(key.fkColumn);
                    }
                    indexCommands.push(fkIndexCommand);
                }
                else
                {
                    insertCommand.addColumn(otm.fkColumn, otm.fkProperty);
                    updateCommand.addColumn(otm.fkColumn, otm.fkProperty);

                    var fkConstraintTable:String = ownerEntity.table;
                    var fkConstraintColumn:String = ownerEntity.pk.column;

                    if (otm.constrain)
                    {
                        createCommand.addFkColumn(otm.fkColumn, SQLType.INTEGER, fkConstraintTable, fkConstraintColumn);
                        createCommandAsync.addFkColumn(otm.fkColumn, SQLType.INTEGER, fkConstraintTable, fkConstraintColumn);
                    }
                    else
                    {
                        createCommand.addColumn(otm.fkColumn, SQLType.INTEGER);
                        createCommandAsync.addColumn(otm.fkColumn, SQLType.INTEGER);
                    }

                    otmDeleteCommand.addFilter(otm.fkColumn, otm.fkProperty);

                    indexName = indexTableName + "_" + otm.fkColumn + "_idx";
                    fkIndexCommand = new CreateIndexCommand(table, indexName, _sqlConnection, _debugLevel);
                    fkIndexCommand.addIndexColumn(otm.fkColumn);
                    indexCommands.push(fkIndexCommand);
                }
                otm.deleteCommand = otmDeleteCommand;

                if (otm.indexed)
                {
                    insertCommand.addColumn(otm.indexColumn, otm.indexProperty);
                    updateCommand.addColumn(otm.indexColumn, otm.indexProperty);
                    createCommand.addColumn(otm.indexColumn, SQLType.INTEGER);
                    createCommandAsync.addColumn(otm.indexColumn, SQLType.INTEGER);

                    indexName = indexTableName + "_" + otm.indexColumn;
                    var otmIndexCommand:CreateIndexCommand = new CreateIndexCommand(table, indexName, _sqlConnection, _debugLevel);
                    otmIndexCommand.addIndexColumn(otm.indexColumn);
                    indexCommands.push(otmIndexCommand);
                }
            }

            for each(var mtm:ManyToManyAssociation in entity.manyToManyAssociations)
            {
                var associationTable:String = mtm.associationTable;
                var associatedEntity:Entity = mtm.associatedEntity;

                var mtmSelectCommand:SelectManyToManyCommand = new SelectManyToManyCommand(associatedEntity.table, associationTable, _sqlConnection, _debugLevel, mtm.indexColumn);
                var mtmInsertCommand:InsertCommand = new InsertCommand(associationTable, _sqlConnection, _debugLevel);
                var mtmDeleteCommand:DeleteCommand = new DeleteCommand(associationTable, _sqlConnection, _debugLevel);
                var selectIndicesCommand:SelectManyToManyIndicesCommand = new SelectManyToManyIndicesCommand(associationTable, _sqlConnection, _debugLevel);
                var mtmCreateCommand:CreateCommand = new CreateCommand(associationTable, _sqlConnection, _debugLevel);
                var mtmCreateCommandAsync:CreateCommandAsync = new CreateCommandAsync(associationTable, _sqlConnection, _debugLevel);
                var mtmUpdateCommand:UpdateCommand = null;

                if (mtm.indexed)
                {
                    mtmInsertCommand.addColumn(mtm.indexColumn, mtm.indexProperty);
                    mtmCreateCommand.addColumn(mtm.indexColumn, SQLType.INTEGER);
                    mtmCreateCommandAsync.addColumn(mtm.indexColumn, SQLType.INTEGER);

                    mtmUpdateCommand = new UpdateCommand(associationTable, _sqlConnection, _debugLevel);
                    mtmUpdateCommand.addColumn(mtm.indexColumn, mtm.indexProperty);

                    indexName = Inflector.singularize(associationTable) + "_" + mtm.indexColumn;
                    var mtmIndexCommand:CreateIndexCommand = new CreateIndexCommand(associationTable, indexName, _sqlConnection, _debugLevel);
                    mtmIndexCommand.addIndexColumn(mtm.indexColumn);
                    indexCommands.push(mtmIndexCommand);
                }

                indexName = Inflector.singularize(associationTable) + "_key_idx";
                fkIndexCommand = new CreateIndexCommand(associationTable, indexName, _sqlConnection, _debugLevel);

                for each(key in associatedEntity.keys)
                {
                    mtmSelectCommand.addJoin(key.fkColumn, key.column);
                    mtmInsertCommand.addColumn(key.fkColumn, key.fkProperty);
                    mtmDeleteCommand.addFilter(key.fkColumn, key.fkProperty);
                    selectIndicesCommand.addColumn(key.fkColumn, key.fkProperty);
                    if (mtm.constrain)
                    {
                        mtmCreateCommand.addFkColumn(key.fkColumn, SQLType.INTEGER, associatedEntity.table, key.column);
                        mtmCreateCommandAsync.addFkColumn(key.fkColumn, SQLType.INTEGER, associatedEntity.table, key.column);
                    }
                    else
                    {
                        mtmCreateCommand.addColumn(key.fkColumn, SQLType.INTEGER);
                        mtmCreateCommandAsync.addColumn(key.fkColumn, SQLType.INTEGER);
                    }
                    if (mtm.indexed)
                    {
                        mtmUpdateCommand.addFilter(key.fkColumn, key.fkProperty);
                    }
                    fkIndexCommand.addIndexColumn(key.fkColumn);
                }

                // entity == mtm.ownerEntity
                for each(key in entity.keys)
                {
                    mtmSelectCommand.addFilter(key.fkColumn, key.fkProperty);
                    selectIndicesCommand.addFilter(key.fkColumn, key.fkProperty);
                    mtmInsertCommand.addColumn(key.fkColumn, key.fkProperty);
                    mtmDeleteCommand.addFilter(key.fkColumn, key.fkProperty);
                    if (mtm.constrain)
                    {
                        mtmCreateCommand.addFkColumn(key.fkColumn, SQLType.INTEGER, entity.table, key.column);
                        mtmCreateCommandAsync.addFkColumn(key.fkColumn, SQLType.INTEGER, entity.table, key.column);
                    }
                    else
                    {
                        mtmCreateCommand.addColumn(key.fkColumn, SQLType.INTEGER);
                        mtmCreateCommandAsync.addColumn(key.fkColumn, SQLType.INTEGER);
                    }
                    if (mtm.indexed)
                    {
                        mtmUpdateCommand.addFilter(key.fkColumn, key.fkProperty);
                    }
                    fkIndexCommand.addIndexColumn(key.fkColumn);
                }

                indexCommands.push(fkIndexCommand);

                mtm.selectIndicesCommand = selectIndicesCommand;
                mtm.selectCommand = mtmSelectCommand;
                mtm.insertCommand = mtmInsertCommand;
                mtm.updateCommand = mtmUpdateCommand;
                mtm.deleteCommand = mtmDeleteCommand;
                mtm.createCommand = mtmCreateCommand;
                mtm.createCommandAsync = mtmCreateCommandAsync;
            }
            entity.findAllCommand = findAllCommand;
            entity.selectCommand = selectCommand;
            entity.insertCommand = insertCommand;
            entity.updateCommand = updateCommand;
            entity.deleteCommand = deleteCommand;
            entity.createCommand = createCommand;
            entity.createCommandAsync = createCommandAsync;
            entity.selectIdMapCommand = selectIdMapCommand;
            entity.selectFkMapCommand = selectFkMapCommand;
            entity.selectUnsynchronisedCommand = selectUnsynchronisedCommand;
            entity.markForDeletionCommand = markForDeletionCommand;
            entity.indexCommands = indexCommands;
        }

        private function getClass(asType:String):Class
        {
            return getDefinitionByName(asType) as Class;
        }

        private function getClassName(c:Class):String
        {
            var qname:String = getQualifiedClassName(c);
            return qname.substring(qname.lastIndexOf(":") + 1);
        }

        private function getClassNameLower(c:Class):String
        {
            var cn:String = getClassName(c);
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
            return loadMetadataForObject(obj, name, name);
        }

        private function loadMetadataForObject(obj:Object, name:String, root:String):Entity
        {
            var c:Class = Class(getDefinitionByName(getQualifiedClassName(obj)));
            var entity:Entity = _map[name];
            if (entity == null)
            {
                entity = new Entity(c, _namingStrategy, name, root);
                _map[name] = entity;
            }
            var deferred:Array = [];
            for (var property:String in obj)
            {
                var column:String;
                if (_namingStrategy == NamingStrategy.CAMEL_CASE_NAMES)
                {
                    column = property;
                }
                else
                {
                    column = StringUtils.underscore(property);
                }

                var value:Object = obj[property];
                if (value)
                {
                    var propertyClass:Class = Class(getDefinitionByName(getQualifiedClassName(value)));
                    var propertyClassName:String = getClassName(propertyClass);
                    if (propertyClassName == "Object")
                    {
                        entity.addManyToOneAssociation(new Association({
                            property: property,
                            associatedEntity: loadMetadataForObject(value, property, root)
                        }));
                    }

                    else if ((value is Array || value is ArrayCollection) &&
                             (value.length > 0))
                    {
                        var item:Object = value[0]; // only need one sample object
                        var itemClass:Class = Class(getDefinitionByName(getQualifiedClassName(item)));
                        var itemClassName:String = getClassName(itemClass);
                        var associatedEntity:Entity;
                        if (itemClassName == "Object")
                        {
                            associatedEntity = _map[property];
                            if (associatedEntity == null)
                            {
                                associatedEntity = new Entity(itemClass, _namingStrategy, property, root);
                                _map[property] = associatedEntity;
                                deferred.push({ type: item, name: property });
                            }
                        }
                        else
                        {
                            associatedEntity = _map[itemClassName];
                            if (associatedEntity == null)
                            {
                                associatedEntity = new Entity(itemClass, _namingStrategy);
                                _map[itemClassName] = associatedEntity;
                                deferred.push({ type: itemClass, name: null });
                            }
                        }
                        var a:OneToManyAssociation = new OneToManyAssociation({
                            property: property,
                            associatedEntity: associatedEntity,
                            fkColumn: entity.fkColumn,
                            fkProperty: entity.fkProperty
                        });
                        associatedEntity.addOneToManyInverseAssociation(a);
                        entity.addOneToManyAssociation(a); // also sets the ownerEntity as entity
                    }

                    else
                    {
                        entity.addField(new Field({
                            property: property,
                            column: column,
                            type: getSQLType(propertyClassName)
                        }));
                    }
                }
            }
            var idProperty:String = "__id";
            obj[idProperty] = 0;
            entity.addIdentity(new PrimaryIdentity({
                property: idProperty,
                column: entity.fkColumn
            }));
            entity.keys = getKeys(entity);
            buildSQLCommands(entity);
            entity.createCommand.execute();
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
                    loadMetadataForClass(def.type, def.name);
                }
            }

            return entity;
        }

    }
}