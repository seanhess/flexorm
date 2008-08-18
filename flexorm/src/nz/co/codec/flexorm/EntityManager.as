package nz.co.codec.flexorm
{
    import flash.data.SQLConnection;
    import flash.errors.SQLError;
    import flash.filesystem.File;
    import flash.utils.getDefinitionByName;
    import flash.utils.getQualifiedClassName;

    import mx.collections.ArrayCollection;
    import mx.collections.IList;

    import nz.co.codec.flexorm.command.DeleteCommand;
    import nz.co.codec.flexorm.command.FindAllCommand;
    import nz.co.codec.flexorm.command.InsertCommand;
    import nz.co.codec.flexorm.command.MarkForDeletionCommand;
    import nz.co.codec.flexorm.command.SelectCommand;
    import nz.co.codec.flexorm.command.SelectManyToManyCommand;
    import nz.co.codec.flexorm.command.SelectManyToManyKeysCommand;
    import nz.co.codec.flexorm.command.SelectSubTypeCommand;
    import nz.co.codec.flexorm.command.UpdateCommand;
    import nz.co.codec.flexorm.criteria.Criteria;
    import nz.co.codec.flexorm.metamodel.AssociatedType;
    import nz.co.codec.flexorm.metamodel.Association;
    import nz.co.codec.flexorm.metamodel.CompositeKey;
    import nz.co.codec.flexorm.metamodel.Entity;
    import nz.co.codec.flexorm.metamodel.Field;
    import nz.co.codec.flexorm.metamodel.Identity;
    import nz.co.codec.flexorm.metamodel.ManyToManyAssociation;
    import nz.co.codec.flexorm.metamodel.OneToManyAssociation;
    import nz.co.codec.flexorm.util.PersistentEntity;

    public class EntityManager extends EntityManagerBase implements IEntityManager
    {
        private static var _instance:EntityManager;

        private static var localInstantiation:Boolean;

        public static function get instance():EntityManager
        {
            if (_instance == null)
            {
                localInstantiation = true;
                _instance = new EntityManager();
                localInstantiation = false;
            }
            return _instance;
        }

        /**
         * EntityManager is a Singleton.
         */
        public function EntityManager()
        {
            super();
            if (!localInstantiation)
            {
                throw new Error("EntityManager is a singleton. Use EntityManager.instance ");
            }
        }

        private var inTransaction:Boolean;

        /**
         * Opens a synchronous connection to the database.
         */
        public function openSyncConnection(dbFilename:String):void
        {
            var dbFile:File = File.applicationStorageDirectory.resolvePath(dbFilename);
            sqlConnection = new SQLConnection();
            sqlConnection.open(dbFile);
        }

        /**
         * Returns the database connection. If no connection, then opens
         * a synchronous connection using a default database name.
         */
        override public function get sqlConnection():SQLConnection
        {
            if (super.sqlConnection == null)
            {
                openSyncConnection("default.db");
            }
            return super.sqlConnection;
        }

        /**
         * Start a programmer-defined transaction.
         */
        public function startTransaction():void
        {
            sqlConnection.begin();
            inTransaction = true;
        }

        /**
         * End a programmer-defined transaction.
         */
        public function endTransaction():void
        {
            if (inTransaction)
            {
                try
                {
                    sqlConnection.commit();
                    inTransaction = false;
                }
                catch (e:SQLError)
                {
                    handleSQLError(e);
                }
            }
        }

        /**
         * Rollback a transaction in the event of a database error and
         * print debug information to the console if set.
         */
        private function handleSQLError(error:SQLError):void
        {
            trace(error);

            // Check if a transaction is still open since a foreign key
            // constraint trigger will force a rollback, which closes
            // the transaction.
            if (sqlConnection.inTransaction)
            {
                sqlConnection.rollback();
            }
            inTransaction = false;
        }

        /**
         * Return a list of all objects of the requested type from the database.
         */
        public function findAll(cls:Class):ArrayCollection
        {
            var entity:Entity = getEntity(cls);
            var cmd:FindAllCommand = entity.findAllCommand;
            cmd.execute();
            var result:ArrayCollection = typeArray(cmd.result, entity);
            clearCache();
            return result;
        }

        /**
         * Return a list of the associated objects in a one-to-many association
         * using a map of the key values (fkProperty : value).
         */
        public function loadOneToManyAssociation(a:OneToManyAssociation, idMap:Object):ArrayCollection
        {
            var result:ArrayCollection = loadOneToManyAssociationInternal(a, idMap);
            clearCache();
            return result;
        }

        private function loadOneToManyAssociationInternal(a:OneToManyAssociation, idMap:Object):ArrayCollection
        {
            var items:Array = [];
            for each(var type:AssociatedType in a.associatedTypes)
            {
                var associatedEntity:Entity = type.associatedEntity;
                var selectCmd:SelectCommand = type.selectCommand;
                setIdentMapParams(selectCmd, idMap);
                selectCmd.execute();

                var row:Object;
                if (associatedEntity.isSuperEntity)
                {
                    var subTypes:Object = {};
                    for each(row in selectCmd.result)
                    {
                        subTypes[row.entity_type] = null;
                    }
                    for (var subType:String in subTypes)
                    {
                        var subClass:Class = getDefinitionByName(subType) as Class;
                        var subEntity:Entity = getEntity(subClass);
                        var selectSubTypeCmd:SelectSubTypeCommand = subEntity.selectSubTypeCmd.clone();
                        selectSubTypeCmd.parentTable = associatedEntity.table;
                        var ownerEntity:Entity = a.ownerEntity;
                        if (ownerEntity.hasCompositeKey())
                        {
                            for each(var identity:Identity in ownerEntity.identities)
                            {
                                selectSubTypeCmd.addFilter(identity.fkColumn, identity.fkProperty);
                                selectSubTypeCmd.setParam(identity.fkProperty, idMap[identity.fkProperty]);
                            }
                        }
                        else
                        {
                            selectSubTypeCmd.addFilter(a.fkColumn, a.fkProperty);
                            selectSubTypeCmd.setParam(a.fkProperty, idMap[a.fkProperty]);
                        }
                        if (a.indexed)
                            selectSubTypeCmd.indexColumn = a.indexColumn;

                        selectSubTypeCmd.execute();
                        for each(row in selectSubTypeCmd.result)
                        {
                            items.push(
                            {
                                associatedEntity: subEntity,
                                index           : row[a.indexColumn],
                                row             : row
                            });
                        }
                    }
                }
                else
                {
                    for each(row in selectCmd.result)
                    {
                        items.push(
                        {
                            associatedEntity: associatedEntity,
                            index           : row[a.indexColumn],
                            row             : row
                        });
                    }
                }
            }
            if (a.indexed)
                items.sortOn("index");

            var result:ArrayCollection = new ArrayCollection();
            for each(var it:Object in items)
            {
                result.addItem(typeObject(it.row, it.associatedEntity));
            }
            return result;
        }

        /**
         * Return a list of the associated objects in a many-to-many association
         * using a map of the key values (fkProperty : value).
         */
        public function loadManyToManyAssociation(a:ManyToManyAssociation, idMap:Object):ArrayCollection
        {
            var selectCmd:SelectManyToManyCommand = a.selectCommand;
            setIdentMapParams(selectCmd, idMap);
            selectCmd.execute();
            return typeArray(selectCmd.result, a.associatedEntity);
        }

        /**
         * Load an object from the database of the requested type and given id.
         */
        public function load(cls:Class, id:int):Object
        {
            return loadItem(cls, id);
        }

        public function loadItem(cls:Class, id:int):Object
        {
            var entity:Entity = getEntity(cls);
            if (entity.hasCompositeKey())
            {
                throw new Error("Entity '" + entity.name + "' has a composite key. " +
                                "Use EntityManager.loadItemByCompositeKey instead. ");
            }
            var instance:Object = loadComplexEntity(entity, getIdentityMap(entity.fkProperty, id));
            clearCache();
            return instance;
        }

        private function loadComplexEntity(entity:Entity, idMap:Object):Object
        {
            var selectCmd:SelectCommand = entity.selectCommand;
            setIdentMapParams(selectCmd, idMap);
            selectCmd.execute();
            var result:Array = selectCmd.result;
            if (result && result.length > 0)
            {
                var row:Object = result[0];

                // Add to cache to avoid reselecting from database
                var instance:Object = typeObject(row, entity);

                if (entity.isSuperEntity)
                {
                    var subType:String = row.entity_type;
                    if (subType)
                    {
                        var subClass:Class = getDefinitionByName(subType) as Class;
                        var subEntity:Entity = getEntity(subClass);
                        if (subEntity == null)
                            throw new Error("Cannot find entity of type " + subType);

                        var map:Object = entity.hasCompositeKey() ?
                            getIdentityMapFromRow(row, subEntity) :
                            getIdentityMap(subEntity.fkProperty, idMap[entity.fkProperty]);

                        var value:Object = getCachedValue(subEntity, map);
                        if (value == null)
                            value = loadComplexEntity(subEntity, map);

                        instance = value;
                    }
                }
            }
            return instance;
        }

        private function loadEntity(entity:Entity, idMap:Object):Object
        {
            var selectCmd:SelectCommand = entity.selectCommand;
            setIdentMapParams(selectCmd, idMap);
            selectCmd.execute();
            var result:Array = selectCmd.result;
            if (result && result.length > 0)
                return typeObject(result[0], entity);
            return null;
        }

        /**
         * Added by WDRogers, 2008-05-16, to enable loading of objects that are
         * referenced by a composite business key.
         */
        public function loadItemByCompositeKey(cls:Class, keys:Array):Object
        {
            var entity:Entity = getEntity(cls);
            if (!entity.hasCompositeKey())
            {
                throw new Error("Entity '" + entity.name +
                    "' does not have a composite key. Use EntityManager.loadItem instead. ");
            }
            var idMap:Object = {};
            for each(var obj:Object in keys)
            {
                var keyEntity:Entity = getEntityForObject(obj);

                // Validate if key is a specified identifier for entity
                var match:Boolean = false;
                for each(var key:CompositeKey in entity.keys)
                {
                    if (keyEntity.equals(key.associatedEntity))
                    {
                        match = true;
                        break;
                    }
                }

                // if not, then check if key type is used in a many-to-one
                // association instead
                if (!match)
                {
                    trace("Key of type '" + keyEntity.name +
                          "' not specified as an identifier for '" + entity.name + "'. ");

                    for each(var a:Association in entity.manyToOneAssociations)
                    {
                        if (keyEntity.equals(a.associatedEntity))
                        {
                            trace("Key type '" + keyEntity.name +
                                  "' is used in a many-to-one association, so will allow. ");
                            match = true;
                            break;
                        }
                    }
                }
                if (match)
                {
                    idMap = combineMaps([idMap, getIdentityMapFromInstance(obj, keyEntity)]);
                }
                else
                {
                    throw new Error("Invalid key of type '" + keyEntity.name + "' specified. ");
                }
            }
            var instance:Object = loadComplexEntity(entity, idMap);
            clearCache();
            return instance;
        }

        /**
         * Insert or update an object into the database, depending on
         * whether the object is new (determined by an id > 0). Metadata
         * for the object, and all associated objects, will be loaded on a
         * just-in-time basis. The save operation and all cascading saves
         * are enclosed in a transaction to ensure the database is left in
         * a consistent state.
         *
         * Options:
         *
         * Externally set:
         * - ownerClass:Class
         *     Must be set if client code specifies an indexValue, to determine
         *     the class that owns the indexed list
         * - indexValue:int
         *     May be set by client code when saving an indexed object directly
         *
         * Internally set:
         * - name:String
         * - a:Association (OneToMany || ManyToMany)
         * - associatedEntity:Entity
         * - idMap:Object
         * - mtmInsertCmd:InsertCommand
         * - indexValue:int
         */
        public function save(obj:Object, opt:Object=null):int
        {
            if (obj == null)
                return 0;

            if (opt == null)
                opt = {};

            resetMapForDynamicObjects(opt.name);
            var id:int = 0;
            try {
                // if not already part of a programmer-defined transaction,
                // then start one to group all cascade 'save-update' operations
                if (!inTransaction)
                {
                    sqlConnection.begin();
                    id = saveItem(obj, opt);
                    sqlConnection.commit();
                }
                else
                {
                    id = saveItem(obj, opt);
                }
            }
            catch (e:SQLError)
            {
                handleSQLError(e);
            }
            return id;
        }

        private function resetMapForDynamicObjects(name:String):void
        {
            if (name)
            {
                for (var key:String in entityMap)
                {
                    var entity:Entity = entityMap[key];
                    if (name == entity.root)
                    {
                        entityMap[key] = null;
                    }
                }
            }
        }

        private function saveItem(obj:Object, opt:Object):int
        {
            if (obj == null)
                return 0;

            var id:int = 0;
            var entity:Entity = getEntityForObject(obj, opt.name);
            if (entity.hasCompositeKey())
            {
                var selectCmd:SelectCommand = entity.selectCommand;

                // Validate that each composite key is not null.
                for each(var key:CompositeKey in entity.keys)
                {
                    var value:Object = obj[key.property];
                    if (value == null)
                        throw new Error("Object of type '" + entity.name + "' has a null key. ");
                }
                setIdentityParams(selectCmd, obj, entity);
                selectCmd.execute();
                var result:Array = selectCmd.result;

                // TODO Seems a bit inefficient to load an item in order to
                // determine whether it is new, but this is the only way I
                // can think of for now without interfering with the object.
                if (result && result[0])
                {
                    updateItem(obj, entity, opt);
                }
                else
                {
                    createItem(obj, entity, opt);
                }
            }
            else
            {
                id = obj[entity.pk.property];
                if (id > 0)
                {
                    updateItem(obj, entity, opt);
                }
                else
                {
                    createItem(obj, entity, opt);
                }
            }
            if (!entity.hasCompositeKey() && id == 0)
            {
                // Set ID from created item
                id = obj[entity.pk.property];
            }
            return id;
        }

        private function createItem(obj:Object, entity:Entity, opt:Object):void
        {
            saveManyToOneAssociations(obj, entity);
            var insertCmd:InsertCommand = entity.insertCommand;
            if (entity.superEntity)
            {
                if (!entity.hasCompositeKey())
                {
                    opt.subInsertCmd = insertCmd;
                    opt.entityType = getQualifiedClassName(entity.cls);
                    opt.fkProperty = entity.fkProperty;
                }
                createItem(obj, entity.superEntity, opt);
            }
            setFieldParams(insertCmd, obj, entity);
            setManyToOneAssociationParams(insertCmd, obj, entity);
            setInsertTimestampParams(insertCmd);

            if (entity.isSuperEntity)
            {
                insertCmd.setParam("entityType", opt.entityType);
            }
            if (opt.syncSupport && !entity.hasCompositeKey())
            {
                insertCmd.setParam("version", 0);
                insertCmd.setParam("serverId", 0);
            }
            insertCmd.setParam("markedForDeletion", false);

            if ((opt.a is OneToManyAssociation) && entity.equals(opt.associatedEntity))
            {
                setIdentMapParams(insertCmd, opt.idMap);
                if (opt.a.indexed)
                    insertCmd.setParam(opt.a.indexProperty, opt.indexValue);
            }
            if (opt.a == null)
            {
                for each(var a:OneToManyAssociation in entity.oneToManyInverseAssociations)
                {
                    if (a.indexed)
                    {
                         // specified by client code
                        if ((a.ownerEntity.cls == opt.ownerClass) && opt.indexValue)
                        {
                            insertCmd.setParam(a.indexProperty, opt.indexValue);
                        }
                        else
                        {
                            insertCmd.setParam(a.indexProperty, 0);
                        }
                    }
                }
            }
            insertCmd.execute();

            if (!entity.hasCompositeKey() && (entity.superEntity == null))
            {
                var id:int = insertCmd.lastInsertRowID;
                var subInsertCmd:InsertCommand = opt.subInsertCmd;
                if (subInsertCmd)
                    subInsertCmd.setParam(opt.fkProperty, id);

                obj[entity.pk.property] = id;
            }

            // The mtmInsertCommand must be executed after the associated entity
            // has been inserted to maintain referential integrity
            if ((opt.a is ManyToManyAssociation) && entity.equals(opt.associatedEntity))
            {
                var mtmInsertCmd:InsertCommand = opt.mtmInsertCmd;
                setIdentityParams(mtmInsertCmd, obj, entity);
                setIdentMapParams(mtmInsertCmd, opt.idMap);
                if (opt.a.indexed)
                    mtmInsertCmd.setParam(opt.a.indexProperty, opt.indexValue);

                mtmInsertCmd.execute();
            }
            saveOneToManyAssociations(obj, entity);
            saveManyToManyAssociations(obj, entity);
        }

        private function updateItem(obj:Object, entity:Entity, opt:Object):void
        {
            if (obj == null || entity == null)
                return;

            saveManyToOneAssociations(obj, entity);
            updateItem(obj, entity.superEntity, opt);
            var updateCmd:UpdateCommand = entity.updateCommand;
            setIdentityParams(updateCmd, obj, entity);
            setFieldParams(updateCmd, obj, entity);
            setManyToOneAssociationParams(updateCmd, obj, entity);
            setUpdateTimestampParams(updateCmd);

            if ((opt.a is OneToManyAssociation) && entity.equals(opt.associatedEntity))
            {
                setIdentMapParams(updateCmd, opt.idMap);
                if (opt.a.indexed)
                    updateCmd.setParam(opt.a.indexProperty, opt.indexValue);
            }
            if (opt.a == null)
            {
                for each(var a:OneToManyAssociation in entity.oneToManyInverseAssociations)
                {
                    if (a.indexed)
                    {
                         // specified by client code
                        if ((a.ownerEntity.cls == opt.ownerClass) && opt.indexValue)
                        {
                            updateCmd.setParam(a.indexProperty, opt.indexValue);
                        }
                        else
                        {
                            updateCmd.setParam(a.indexProperty, 0);
                        }
                    }
                }
            }
            updateCmd.execute();

            // The mtmInsertCmd must be executed after the associated entity has
            // been inserted to maintain referential integrity.
            if ((opt.a is ManyToManyAssociation) && entity.equals(opt.associatedEntity))
            {
                var mtmInsertCmd:InsertCommand = opt.mtmInsertCmd;
                setIdentityParams(mtmInsertCmd, obj, entity);
                setIdentMapParams(mtmInsertCmd, opt.idMap);
                if (opt.a.indexed)
                    mtmInsertCmd.setParam(opt.a.indexProperty, opt.indexValue);

                mtmInsertCmd.execute();
            }
            saveOneToManyAssociations(obj, entity);
            saveManyToManyAssociations(obj, entity);
        }

        private function saveManyToOneAssociations(obj:Object, entity:Entity):void
        {
            for each(var a:Association in entity.manyToOneAssociations)
            {
                var value:Object = obj[a.property];
                if (value && !a.inverse && isCascadeSave(a))
                {
                    if (isDynamicObject(value))
                    {
                        saveItem(value, { name: a.property });
                    }
                    else
                    {
                        saveItem(value, {});
                    }
                }
            }
        }

        private function saveOneToManyAssociations(obj:Object, entity:Entity):void
        {
            var idMap:Object = null;
            if (entity.hasCompositeKey())
            {
                idMap = getIdentityMapFromInstance(obj, entity);
            }
            for each(var a:OneToManyAssociation in entity.oneToManyAssociations)
            {
                var value:IList = obj[a.property];
                if (value && !a.inverse && (!a.lazy || !(value is LazyList) || LazyList(value).loaded) && isCascadeSave(a))
                {
                    if (!entity.hasCompositeKey())
                    {
                        idMap = getIdentityMap(a.fkProperty, obj[entity.pk.property]);
                    }
                    for (var i:int = 0; i < value.length; i++)
                    {
                        var item:Object = value.getItemAt(i);
                        var itemClass:Class = getClass(item);
                        var itemCN:String = getClassName(itemClass);

                        var itemEntity:Entity = (OBJECT_TYPE == itemCN)?
                            getEntityForDynamicObject(item, a.property) :
                            getEntity(itemClass);

                        var associatedEntity:Entity = a.getAssociatedEntity(itemEntity);
                        if (associatedEntity)
                        {
                            var opt:Object = {
                                a               : a,
                                associatedEntity: associatedEntity,
                                idMap           : idMap
                            };
                            if (a.indexed)
                                opt.indexValue = i;

                            if (associatedEntity.isDynamicObject())
                                opt.name = a.property;

                            saveItem(item, opt);
                        }
                        else
                        {
                            throw new Error("Attempting to save a collection " +
                                            "item of a type not specified in " +
                                            "the one-to-many association. ");
                        }
                    }
                }
            }
        }

        private function saveManyToManyAssociations(obj:Object, entity:Entity):void
        {
            for each(var a:ManyToManyAssociation in entity.manyToManyAssociations)
            {
                var value:IList = obj[a.property];
                if (value && (!a.lazy || LazyList(value).loaded))
                {
                    var idMap:Object = getIdentityMapFromInstance(obj, entity);

                    var selectExistingCmd:SelectManyToManyKeysCommand = a.selectManyToManyKeysCmd;
                    setIdentityParams(selectExistingCmd, obj, entity);
                    selectExistingCmd.execute();

                    var existing:Array = [];
                    for each(var row:Object in selectExistingCmd.result)
                    {
                        existing.push(getIdentityMapFromAssociation(row, a.associatedEntity));
                    }

                    var map:Object;
                    for (var i:int = 0; i < value.length; i++)
                    {
                        var item:Object = value.getItemAt(i);
                        var itemIdMap:Object = getIdentityMapFromInstance(item, a.associatedEntity);

                        var isLinked:Boolean = false;
                        var k:int = 0;
                        for each(map in existing)
                        {
                            isLinked = true;
                            for each(var identity:Identity in a.associatedEntity.identities)
                            {
                                if (itemIdMap[identity.fkProperty] != map[identity.fkProperty])
                                {
                                    isLinked = false;
                                    break;
                                }
                            }
                            if (isLinked)
                                break;
                            k++;
                        }

                        if (isLinked) // then no need to create the associationTable
                        {
                            if (isCascadeSave(a))
                            {
                                if (a.indexed)
                                {
                                    var updateCmd:UpdateCommand = a.updateCommand;
                                    setIdentMapParams(updateCmd, idMap);
                                    setIdentMapParams(updateCmd, itemIdMap);
                                    updateCmd.setParam(a.indexProperty, i);
                                    updateCmd.execute();
                                }
                                saveItem(item, {});
                            }
                            existing.splice(k, 1);
                        }
                        else
                        {
                            var insertCmd:InsertCommand = a.insertCommand;
                            if (isCascadeSave(a))
                            {
                                // insert link in associationTable after
                                // inserting the associated entity instance
                                var opt:Object = {
                                    a               : a,
                                    associatedEntity: a.associatedEntity,
                                    idMap           : idMap,
                                    mtmInsertCmd    : insertCmd
                                }
                                if (a.indexed)
                                    opt.indexValue = i;

                                saveItem(item, opt);
                            }
                            else // just create the link instead
                            {
                                setIdentMapParams(insertCmd, idMap);
                                setIdentMapParams(insertCmd, itemIdMap);
                                if (a.indexed)
                                    insertCmd.setParam(a.indexProperty, i);

                                insertCmd.execute();
                            }
                        }
                    }
                    // for each pre index left
                    for each(map in existing)
                    {
                        // delete link from associationTable
                        var deleteCmd:DeleteCommand = a.deleteCommand;
                        setIdentMapParams(deleteCmd, idMap);
                        setIdentMapParams(deleteCmd, map);
                        deleteCmd.execute();
                    }
                }
            }
        }

        public function markForDeletion(obj:Object):void
        {
            var entity:Entity = getEntityForObject(obj);
            var markForDeletionCmd:MarkForDeletionCommand = entity.markForDeletionCmd;
            setIdentityParams(markForDeletionCmd, obj, entity);
            markForDeletionCmd.execute();
        }

        public function removeItem(cls:Class, id:int):void
        {
            remove(loadItem(cls, id));
        }

        public function removeItemByCompositeKey(cls:Class, compositeKeys:Array):void
        {
            remove(loadItemByCompositeKey(cls, compositeKeys));
        }

        public function remove(obj:Object):void
        {
            // if not already part of a programmer-defined transaction,
            // then start one to group all cascade 'delete' operations
            try {
                if (!inTransaction)
                {
                    sqlConnection.begin();
                    removeObject(obj);
                    sqlConnection.commit();
                }
                else
                {
                    removeObject(obj);
                }
            }
            catch (e:SQLError)
            {
                handleSQLError(e);
            }
        }

        private function removeObject(obj:Object):void
        {
            removeEntity(getEntityForObject(obj), obj);
        }

        private function removeEntity(entity:Entity, obj:Object):void
        {
            if (entity == null)
                return;

            removeOneToManyAssociations(entity, obj);

            // Doesn't make sense to support 'cascade delete' on many-to-many
            // associations

            // obj must be concrete therefore I do not need to worry if entity
            // is a superEntity

            var deleteCmd:DeleteCommand = entity.deleteCommand;
            setIdentityParams(deleteCmd, obj, entity);
            deleteCmd.execute();
            removeEntity(entity.superEntity, obj);
            removeManyToOneAssociations(entity, obj);
        }

        private function removeOneToManyAssociations(entity:Entity, obj:Object):void
        {
            for each(var a:OneToManyAssociation in entity.oneToManyAssociations)
            {
                if (isCascadeDelete(a))
                {
                    if (a.multiTyped)
                    {
                        for each(var type:AssociatedType in a.associatedTypes)
                        {
                            removeEntity(type.associatedEntity, obj);
                        }
                    }
                    else
                    {
                        var deleteCmd:DeleteCommand = a.deleteCommand;
                        if (entity.hasCompositeKey())
                        {
                            setIdentityParams(deleteCmd, obj, entity);
                        }
                        else
                        {
                            deleteCmd.setParam(a.fkProperty, obj[entity.pk.property]);
                        }
                        deleteCmd.execute();
                    }
                }
                // TODO else set the FK to 0 ?
            }
        }

        private function removeManyToOneAssociations(entity:Entity, obj:Object):void
        {
            for each(var a:Association in entity.manyToOneAssociations)
            {
                var value:Object = obj[a.property];
                if (value && isCascadeDelete(a))
                {
                    removeObject(value);
                }
            }
        }

        private function typeArray(array:Array, entity:Entity):ArrayCollection
        {
            var coll:ArrayCollection = new ArrayCollection();
            for each(var row:Object in array)
            {
                coll.addItem(typeObject(row, entity));
            }
            return coll;
        }

        private function typeObject(row:Object, entity:Entity):Object
        {
            if (row == null)
                return null;

            var value:Object = getCachedValue(entity, getIdentityMapFromRow(row, entity));
            if (value)
                return value;

            var instance:Object = new entity.cls();
            for each(var f:Field in entity.fields)
            {
                instance[f.property] = row[f.column];
            }
            loadSuperProperties(instance, row, entity);
            loadManyToOneAssociations(instance, row, entity);

            // Must be after keys on instance has been loaded, which includes:
            // - loadManyToOneAssociations to load composite keys, and
            // - loadSuperProperties to load inherited keys.
            setCachedValue(instance, entity);

            loadOneToManyAssociations(instance, row, entity);
            loadManyToManyAssociations(instance, row, entity);

            return instance;
        }

        private function loadSuperProperties(instance:Object, row:Object, entity:Entity):void
        {
            var superEntity:Entity = entity.superEntity;
            if (superEntity == null)
                return;

            var idMap:Object = entity.hasCompositeKey() ?
                getIdentityMapFromRow(row, superEntity) :
                getIdentityMap(superEntity.fkProperty, row[entity.pk.column]);

            var superInstance:Object = getCachedValue(superEntity, idMap);
            if (superInstance == null)
            {
                superInstance = loadEntity(superEntity, idMap);
            }
            for each(var f:Field in superEntity.fields)
            {
                // commented out to populate a sub instance's inherited ID field
//                if (superEntity.hasCompositeKey() || (f.property != superEntity.pk.property))
//                {
                    instance[f.property] = superInstance[f.property];
//                }
            }
            for each(var mto:Association in superEntity.manyToOneAssociations)
            {
                instance[mto.property] = superInstance[mto.property];
            }
            for each(var otm:OneToManyAssociation in superEntity.oneToManyAssociations)
            {
                instance[otm.property] = superInstance[otm.property];
            }
            for each(var mtm:ManyToManyAssociation in superEntity.manyToManyAssociations)
            {
                instance[mtm.property] = superInstance[mtm.property];
            }
        }

        private function loadManyToOneAssociations(instance:Object, row:Object, entity:Entity):void
        {
            for each(var a:Association in entity.manyToOneAssociations)
            {
                var associatedEntity:Entity = a.associatedEntity;
                var value:Object = null;
                if (!associatedEntity.isSuperEntity)
                {
                    value = getCachedAssociationValue(a, row);
                }
                if (value)
                {
                    instance[a.property] = value;
                }
                else
                {
                    var idMap:Object = null;
                    if (associatedEntity.hasCompositeKey())
                    {
                        idMap = getIdentityMapFromAssociation(row, associatedEntity);
                    }
                    else
                    {
                        var id:int = row[a.fkColumn];
                        if (id > 0)
                        {
                            idMap = getIdentityMap(associatedEntity.fkProperty, id);
                        }
                    }
                    if (idMap)
                    {
                        // May return no result if a.ownerEntity (FK) has been
                        // deleted and the association was not set to
                        // 'cascade-delete'
                        instance[a.property] = loadComplexEntity(associatedEntity, idMap);
                    }
                }
            }
        }

        private function loadOneToManyAssociations(instance:Object, row:Object, entity:Entity):void
        {
            for each(var a:OneToManyAssociation in entity.oneToManyAssociations)
            {
                var idMap:Object = entity.hasCompositeKey() ?
                    getIdentityMapFromRow(row, entity) :
                    getIdentityMap(a.fkProperty, row[entity.pk.column]);
                if (a.lazy)
                {
                    var lazyList:LazyList = new LazyList(this, a, idMap);
                    var value:ArrayCollection = new ArrayCollection();
                    value.list = lazyList;
                    instance[a.property] = value;
                    lazyList.initialise();
                }
                else
                {
                    instance[a.property] = loadOneToManyAssociationInternal(a, idMap);
                }
            }
        }

        private function loadManyToManyAssociations(instance:Object, row:Object, entity:Entity):void
        {
            for each(var a:ManyToManyAssociation in entity.manyToManyAssociations)
            {
                if (a.lazy)
                {
                    var lazyList:LazyList = new LazyList(this, a, getIdentityMapFromRow(row, entity));
                    var value:ArrayCollection = new ArrayCollection();
                    value.list = lazyList;
                    instance[a.property] = value;
                    lazyList.initialise();
                }
                else
                {
                    instance[a.property] = selectManyToManyAssociation(a, row);
                }
            }
        }

        private function selectManyToManyAssociation(a:ManyToManyAssociation, row:Object):ArrayCollection
        {
            var selectCmd:SelectManyToManyCommand = a.selectCommand;
            setIdentMapParams(selectCmd, getIdentityMapFromRow(row, a.ownerEntity));
            selectCmd.execute();
            return typeArray(selectCmd.result, a.associatedEntity);
        }

        public function createCriteria(cls:Class):Criteria
        {
            var entity:Entity = getEntity(cls);
            return entity.criteria;
        }

        public function fetchCriteria(crit:Criteria):ArrayCollection
        {
            crit.execute();
            return typeArray(crit.result, crit.entity);
        }

        public function fetchCriteriaUniq(crit:Criteria):Object
        {
            crit.execute();
            var result:ArrayCollection = typeArray(crit.result, crit.entity);
            return (result.length > 0)? result[0] : null;
        }

        /**
         * Returns metadata for a persistent object. If not already defined,
         * then uses the EntityIntrospector to load metadata using the
         * persistent object's annotations.
         */
        private function getEntity(cls:Class):Entity
        {
            var c:Class = (cls is PersistentEntity)? cls.__class : cls;
            var cn:String = getClassName(c);
            var entity:Entity = entityMap[cn];
            if (entity == null || !entity.initialisationComplete)
            {
                entity = introspector.loadMetadata(c);
            }
            return entity;
        }

        /**
         * Helper method added by WDRogers, 2008-05-16
         */
        private function getEntityForObject(obj:Object, name:String=null):Entity
        {
            if (obj == null)
                return null;

            var c:Class = getClass(obj);
            var cn:String = getClassName(c);
            if (OBJECT_TYPE == cn)
            {
                return getEntityForDynamicObject(obj, name);
            }
            else
            {
                return getEntity(c);
            }
        }

        private function getEntityForDynamicObject(obj:Object, name:String):Entity
        {
            if (name == null)
                throw new Error("Name must be specified for a dynamic object. ");

            var entity:Entity = entityMap[name];
            if (entity == null || !entity.initialisationComplete)
            {
                entity = introspector.loadMetadataForDynamicObject(obj, name);
            }
            return entity;
        }

        /**
         * !! Not fully implemented. Need to save metadata to the database since
         * annotations are not available as persistent memory on dynamic objects.
         */
        public function loadDynamicObject(name:String, id:int):Object
        {
            var entity:Entity = entityMap[name];
            if (entity == null)
                return null;

            var instance:Object = loadEntity(entity, getIdentityMap(entity.fkProperty, id));
            clearCache();
            return instance;
        }

    }
}