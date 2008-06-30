package nz.co.codec.flexorm
{
    import flash.data.SQLConnection;
    import flash.errors.SQLError;
    import flash.filesystem.File;

    import mx.collections.ArrayCollection;
    import mx.collections.IList;

    import nz.co.codec.flexorm.command.DeleteCommand;
    import nz.co.codec.flexorm.command.FindAllCommand;
    import nz.co.codec.flexorm.command.InsertCommand;
    import nz.co.codec.flexorm.command.MarkForDeletionCommand;
    import nz.co.codec.flexorm.command.SelectCommand;
    import nz.co.codec.flexorm.command.SelectManyToManyCommand;
    import nz.co.codec.flexorm.command.SelectManyToManyIndicesCommand;
    import nz.co.codec.flexorm.command.UpdateCommand;
    import nz.co.codec.flexorm.metamodel.Association;
    import nz.co.codec.flexorm.metamodel.CompositeIdentity;
    import nz.co.codec.flexorm.metamodel.Entity;
    import nz.co.codec.flexorm.metamodel.Field;
    import nz.co.codec.flexorm.metamodel.Key;
    import nz.co.codec.flexorm.metamodel.ManyToManyAssociation;
    import nz.co.codec.flexorm.metamodel.OneToManyAssociation;
    import nz.co.codec.flexorm.metamodel.PrimaryIdentity;
    import nz.co.codec.flexorm.util.PersistentEntity;

    public class EntityManager extends EntityManagerBase implements IEntityManager
    {
        private static var _instance:EntityManager;

        private static var localInstantiation:Boolean = false;

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

        private var inTransaction:Boolean = false;

        /**
         * EntityManager is a singleton.
         */
        public function EntityManager()
        {
            super();
            if (!localInstantiation)
            {
                throw new Error("EntityManager is a singleton. Use EntityManager.instance");
            }
        }

        /**
         * Opens a synchronous connection to the database.
         */
        public function openSyncConnection(dbFilename:String):void
        {
            var dbFile:File = File.applicationStorageDirectory.resolvePath(dbFilename);
            _sqlConnection = new SQLConnection();
            _sqlConnection.open(dbFile);
            introspector = null;
        }

        /**
         * Returns the database connection. If no connection, then opens
         * a synchronous connection using a default database name.
         */
        override public function get sqlConnection():SQLConnection
        {
            if (_sqlConnection == null)
            {
                openSyncConnection("default.db");
            }
            return _sqlConnection;
        }

        /**
         * Returns metadata for a persistent object. If not already defined,
         * then uses the EntityReflector to load metadata using the
         * persistent object's annotations.
         */
        private function getEntity(cls:Class, name:String=null):Entity
        {
            var c:Class = (cls is PersistentEntity)? cls.myClass : cls;
            var cn:String = getClassName(c);
            var entity:Entity = map[cn];
            if (entity == null || !entity.initialisationComplete)
            {
                entity = introspector.loadMetadata(c, name);
            }
            return entity;
        }

        /**
         * Helper method added by WDRogers, 2008-05-16
         */
        private function getEntityForObject(obj:Object, name:String=null):Entity
        {
            var c:Class = getClass(obj);
            var cn:String = getClassName(c);
            if (cn == "Object")
            {
                if (name == null)
                    throw Error("Object name must be specified if attempting to save an untyped object.");

                var entity:Entity = map[name];
                if (entity == null || !entity.initialisationComplete)
                {
                    entity = introspector.loadMetadataForDynamicObject(obj, name);
                }
                return entity;
            }
            else
            {
                return getEntity(c, name);
            }
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
         * Rollback a transaction in the event of a database error
         * and print debug information to the console if set.
         */
        private function handleSQLError(error:SQLError):void
        {
            if (debugLevel > 0)
                trace(error);

            // check if transaction is still open, since a foreign key
            // constraint trigger will force a rollback, which closes
            // the transaction
            if (sqlConnection.inTransaction)
            {
                sqlConnection.rollback();
            }
            inTransaction = false;
        }

        /**
         * Return a list of all persistent objects of the requested type
         * from the database.
         */
        public function findAll(c:Class):ArrayCollection
        {
            var entity:Entity = getEntity(c);
            var command:FindAllCommand = entity.findAllCommand;
            command.execute();
            return typeArray(command.result, entity);
        }

        private function loadItems(selectCommand:SelectCommand, keyMap:Object, entity:Entity):ArrayCollection
        {
            setKeyMapParams(selectCommand, keyMap);
            selectCommand.execute();
            return typeArray(selectCommand.result, entity);
        }

        /**
         * Return a list of the associated objects in a one-to-many association
         * using a map of the foreign key IDs.
         */
        public function loadOneToManyAssociation(a:OneToManyAssociation, keyMap:Object):ArrayCollection
        {
            return loadItems(a.selectCommand, keyMap, a.associatedEntity);
        }

        /**
         * Return a list of the associated objects in a many-to-many association
         * using a map of the foreign key IDs.
         */
        public function loadManyToManyAssociation(a:ManyToManyAssociation, keyMap:Object):ArrayCollection
        {
            var selectCommand:SelectManyToManyCommand = a.selectCommand;
            setKeyMapParams(selectCommand, keyMap);
            selectCommand.execute();
            return typeArray(selectCommand.result, a.associatedEntity);
        }

        /**
         * Load a persistent object from the database of the requested type
         * and given id.
         */
        public function loadItem(c:Class, id:int):Object
        {
            var entity:Entity = getEntity(c);
            if (entity.hasCompositeKey())
            {
                throw new Error("Entity '" + entity.className +
                    "' has a composite key. Use EntityManager.loadItemByCompositeKey instead.");
            }

            var selectCommand:SelectCommand = entity.selectCommand;
            selectCommand.setParam(entity.pk.property, id);
            selectCommand.execute();
            return selectCommand.result? typeObject(selectCommand.result[0], entity) : null;
        }

        public function load(cls:Class, id:int):Object
        {
            return loadItem(cls, id);
        }

        public function loadObject(name:String, id:int):Object
        {
            var entity:Entity = map[name];
            if (entity == null)
                return null;

            var selectCommand:SelectCommand = entity.selectCommand;
            selectCommand.setParam(entity.pk.property, id);
            selectCommand.execute();
            return selectCommand.result? typeObject(selectCommand.result[0], entity) : null;
        }

        /**
         * Added by WDRogers, 2008-05-16 to provide loading of objects that
         * are most conveniently referenced by a composite business key.
         */
        public function loadItemByCompositeKey(c:Class, compositeKeys:Array):Object
        {
            var entity:Entity = getEntity(c);
            if (!entity.hasCompositeKey())
            {
                throw new Error("Entity '" + entity.className +
                    "' does not have a composite key. Use EntityManager.load instead.");
            }

            var selectCommand:SelectCommand = entity.selectCommand;
            for each(var obj:Object in compositeKeys)
            {
                var keyEntity:Entity = getEntityForObject(obj);
                var key:Key;

                // validate if key is a specified identifier for entity
                var match:Boolean = false;
                for each(var identity:CompositeIdentity in entity.identities)
                {
                    if (identity.associatedEntity.className == keyEntity.className)
                    {
                        for each(key in keyEntity.keys)
                        {
                            selectCommand.setParam(key.fkProperty, key.getIdValue(obj));
                        }
                        match = true;
                        break;
                    }
                }

                // if not, then check if key type is used in a many-to-one
                // association instead
                if (!match)
                {
                    trace("Key of type '" + keyEntity.className +
                          "' not specified as an identifier for '" +
                          entity.className + "'.");

                    for each(var a:Association in entity.manyToOneAssociations)
                    {
                        if (a.associatedEntity.className == keyEntity.className)
                        {
                            trace("Key type '" + keyEntity.className +
                                  "' is used in a many-to-one association, so will allow.");

                            for each(key in keyEntity.keys)
                            {
                                selectCommand.setParam(key.fkProperty, key.getIdValue(obj));
                            }
                            match = true;
                            break;
                        }
                    }
                }
                if (!match)
                    throw new Error("Invalid key of type '" + keyEntity.className + "' specified.");
            }

            selectCommand.execute();
            var result:Array = selectCommand.result;
            return result? typeObject(result[0], entity) : null;
        }

        /**
         * Insert or update an object into the database, depending on
         * whether the object is new (determined by an id > 0). Metadata
         * for the object, and all associated objects, will be loaded on a
         * just-in-time basis. The save operation and all cascading saves
         * are enclosed in a transaction to ensure the database is left in
         * a consistent state.
         */
        public function save(obj:Object, name:String=null):int
        {
            resetMapForDynamicObjects(name);
            var id:int = 0;
            // if not already part of a user-defined transaction, then
            // start one to group all cascade 'save-update' operations
            try {
                if (!inTransaction)
                {
                    sqlConnection.begin();
                    id = saveItem(obj, name);
                    sqlConnection.commit();
                }
                else
                {
                    id = saveItem(obj, name);
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
                for (var key:String in map)
                {
                    var entity:Entity = map[key];
                    if (entity.root == name)
                    {
                        map[key] = null;
                    }
                }
            }
        }

        private function saveItem(
            obj:Object,
            name:String=null,
            foreignKeys:Array=null,
            mtmInsertCommand:InsertCommand=null,
            idx:Object=null):int
        {
            if (obj == null)
                return 0;

            var entity:Entity = getEntityForObject(obj, name);

            if (entity.hasCompositeKey())
            {
                var selectCommand:SelectCommand = entity.selectCommand;
                for each(var identity:CompositeIdentity in entity.identities)
                {
                    var keyVal:Object = obj[identity.property];
                    if (keyVal == null)
                    {
                        throw new Error("Object of type '" + entity.className + "' has a null key.");
                    }
                }
                setKeyParams(selectCommand, obj, entity);
                selectCommand.execute();
                var result:Array = selectCommand.result;

                // TODO Seems a bit inefficient to load an item in order
                // to determine whether it is new, but this is the only
                // way I can think of for now without interfering with
                // the persistent object.
                if (result && result[0])
                {
                    updateItem(obj, entity, foreignKeys, mtmInsertCommand, idx);
                }
                else
                {
                    createItem(obj, entity, foreignKeys, mtmInsertCommand, idx);
                }
            }
            else
            {
                var id:int = obj[entity.pk.property];
                if (id > 0)
                {
                    updateItem(obj, entity, foreignKeys, mtmInsertCommand, idx);
                }
                else
                {
                    createItem(obj, entity, foreignKeys, mtmInsertCommand, idx);
                }
            }
            saveOneToManyAssociations(obj, entity);
            saveManyToManyAssociations(obj, entity);
            if (entity.hasCompositeKey())
            {
                return 0;
            }
            else
            {
                return obj[entity.pk.property];
            }
        }

        private function updateItem(
            obj:Object,
            entity:Entity,
            foreignKeys:Array,
            mtmInsertCommand:InsertCommand,
            idx:Object):void
        {
            saveManyToOneAssociations(obj, entity);
            updateSuperEntity(obj, entity.superEntity);
            var updateCommand:UpdateCommand = entity.updateCommand;
            setKeyParams(updateCommand, obj, entity);
            setFieldParams(updateCommand, obj, entity);
            setManyToOneAssociationParams(updateCommand, obj, entity);
            setUpdateTimestampParams(updateCommand);

            if (foreignKeys && !mtmInsertCommand)
            {
                setForeignKeyParams(updateCommand, foreignKeys);
                if (idx)
                {
                    updateCommand.setParam(idx.property, idx.value);
                }
            }
            updateCommand.execute();

            // The mtmInsertCommand must be executed after the associated entity
            // has been inserted to maintain relational integrity
            if (foreignKeys && mtmInsertCommand)
            {
                setFkParams(mtmInsertCommand, obj, entity);
                setForeignKeyParams(mtmInsertCommand, foreignKeys);
                if (idx)
                {
                    mtmInsertCommand.setParam(idx.property, idx.value);
                }
                mtmInsertCommand.execute();
            }
        }

        private function createItem(
            obj:Object,
            entity:Entity,
            foreignKeys:Array,
            mtmInsertCommand:InsertCommand,
            idx:Object):void
        {
            saveManyToOneAssociations(obj, entity);
            var insertCommand:InsertCommand = entity.insertCommand;
            createSuperEntity(insertCommand, obj, entity.superEntity);
            setFieldParams(insertCommand, obj, entity);
            setManyToOneAssociationParams(insertCommand, obj, entity);
            setInsertTimestampParams(insertCommand);

            if (syncSupport && !entity.hasCompositeKey())
            {
                insertCommand.setParam("serverId", 0);
            }
            insertCommand.setParam("markedForDeletion", false);

            if (foreignKeys && !mtmInsertCommand)
            {
                setForeignKeyParams(insertCommand, foreignKeys);
                if (idx)
                {
                    insertCommand.setParam(idx.property, idx.value);
                }
            }
            insertCommand.execute();

            if (!entity.hasCompositeKey() && entity.superEntity == null)
            {
                obj[entity.pk.property] = insertCommand.lastInsertRowID;
            }

            // The mtmInsertCommand must be executed after the associated entity
            // has been inserted to maintain relational integrity
            if (foreignKeys && mtmInsertCommand)
            {
                setFkParams(mtmInsertCommand, obj, entity);
                setForeignKeyParams(mtmInsertCommand, foreignKeys);
                if (idx)
                {
                    mtmInsertCommand.setParam(idx.property, idx.value);
                }
                mtmInsertCommand.execute();
            }
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
                        saveItem(value, a.property);
                    }
                    else
                    {
                        saveItem(value);
                    }
                }
            }
        }

        private function createSuperEntity(insertCommand:InsertCommand, obj:Object, superEntity:Entity):void
        {
            if (superEntity == null)
                return;

            saveManyToOneAssociations(obj, superEntity);
            var superInsertCommand:InsertCommand = superEntity.insertCommand;

            if (syncSupport && !superEntity.hasCompositeKey())
            {
                superInsertCommand.setParam("serverId", 0);
            }
            superInsertCommand.setParam("markedForDeletion", false);

            setFieldParams(superInsertCommand, obj, superEntity);
            setManyToOneAssociationParams(superInsertCommand, obj, superEntity);
            setInsertTimestampParams(superInsertCommand);
            superInsertCommand.execute();
            if (!superEntity.hasCompositeKey())
            {
                var id:int = superInsertCommand.lastInsertRowID;
                var pk:PrimaryIdentity = superEntity.pk;
                insertCommand.setParam(pk.property, id);
                obj[pk.property] = id;
            }
        }

        private function updateSuperEntity(obj:Object, superEntity:Entity):void
        {
            if (superEntity == null)
                return;

            saveManyToOneAssociations(obj, superEntity);
            var superUpdateCommand:UpdateCommand = superEntity.updateCommand;
            setFieldParams(superUpdateCommand, obj, superEntity);
            if (!superEntity.hasCompositeKey())
            {
                var pk:PrimaryIdentity = superEntity.pk;
                var id:int = obj[pk.property];
                superUpdateCommand.setParam(pk.property, id);
            }
            setManyToOneAssociationParams(superUpdateCommand, obj, superEntity);
            setUpdateTimestampParams(superUpdateCommand);
            superUpdateCommand.execute();
        }

        private function saveOneToManyAssociations(obj:Object, entity:Entity):void
        {
            var foreignKeys:Array;
            if (entity.hasCompositeKey())
            {
                foreignKeys = getForeignKeys(obj, entity);
            }
            for each(var a:OneToManyAssociation in entity.oneToManyAssociations)
            {
                var value:IList = obj[a.property];
                if (value && !a.inverse && (!a.lazy || LazyList(value).loaded) && isCascadeSave(a))
                {
                    if (!entity.hasCompositeKey())
                    {
                        foreignKeys = [{ property: a.fkProperty, id: obj[entity.pk.property] }];
                    }
                    for (var i:int = 0; i < value.length; i++)
                    {
                        if (a.indexed)
                        {
                            saveItem(value.getItemAt(i), null, foreignKeys, null, { property: a.indexProperty, value: i });
                        }
                        else
                        {
                            if (a.associatedEntity.isDynamicObject())
                            {
                                saveItem(value.getItemAt(i), a.property, foreignKeys);
                            }
                            else
                            {
                                saveItem(value.getItemAt(i), null, foreignKeys);
                            }
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
                    var foreignKeys:Array = getForeignKeys(obj, entity);

                    var selectIndicesCommand:SelectManyToManyIndicesCommand = a.selectIndicesCommand;
                    setFkParams(selectIndicesCommand, obj, entity);
                    selectIndicesCommand.execute();

                    var key:Key;

                    var preIndices:Array = [];
                    for each(var row:Object in selectIndicesCommand.result)
                    {
                        var index:Object = new Object();
                        for each(key in a.associatedEntity.keys)
                        {
                            index[key.fkProperty] = row[key.fkColumn];
                        }
                        preIndices.push(index);
                    }

                    var idx:Object;
                    for (var i:int = 0; i < value.length; i++)
                    {
                        var item:Object = value.getItemAt(i);
                        var idm:Object = new Object();
                        for each(key in a.associatedEntity.keys)
                        {
                            idm[key.fkProperty] = key.getIdValue(item);
                        }

                        var isLinked:Boolean = false;
                        var k:int = 0;

                        for each(idx in preIndices)
                        {
                            isLinked = true;
                            for each(key in a.associatedEntity.keys)
                            {
                                if (idm[key.fkProperty] != idx[key.fkProperty])
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
                                    var updateCommand:UpdateCommand = a.updateCommand;
                                    setFkParams(updateCommand, obj, entity);
                                    setFkParams(updateCommand, item, a.associatedEntity);
                                    updateCommand.setParam(a.indexProperty, i);
                                    updateCommand.execute();
                                }
                                saveItem(item);
                            }
                            preIndices.splice(k, 1);
                        }
                        else
                        {
                            var insertCommand:InsertCommand = a.insertCommand;
                            if (isCascadeSave(a))
                            {
                                // insert link in associationTable after
                                // inserting the associated entity instance
                                if (a.indexed)
                                {
                                    saveItem(item, null, foreignKeys, insertCommand, { property: a.indexProperty, value: i });
                                }
                                else
                                {
                                    saveItem(item, null, foreignKeys, insertCommand);
                                }
                            }
                            else // just create the link instead
                            {
                                setFkParams(insertCommand, obj, entity);
                                setFkParams(insertCommand, item, a.associatedEntity);
                                if (a.indexed)
                                {
                                    insertCommand.setParam(a.indexProperty, i);
                                }
                                insertCommand.execute();
                            }
                        }
                    }
                    // for each pre index left
                    for each(idx in preIndices)
                    {
                        // delete link from associationTable
                        var deleteCommand:DeleteCommand = a.deleteCommand;
                        for each(key in a.associatedEntity.keys)
                        {
                            deleteCommand.setParam(key.fkProperty, idx[key.fkProperty]);
                        }
                        setFkParams(deleteCommand, obj, entity);
                        deleteCommand.execute();
                    }
                }
            }
        }

        public function markForDeletion(obj:Object):void
        {
            var entity:Entity = getEntityForObject(obj);
            var markForDeletionCommand:MarkForDeletionCommand = entity.markForDeletionCommand;
            setKeyParams(markForDeletionCommand, obj, entity);
            markForDeletionCommand.execute();
        }

        public function remove(obj:Object):void
        {
            // if not already part of a user-defined transaction, then
            // start one to group all cascade 'delete' operations
            try {
                if (!inTransaction)
                {
                    sqlConnection.begin();
                    removeObj(obj);
                    sqlConnection.commit();
                }
                else
                {
                    removeObj(obj);
                }
            }
            catch (e:SQLError)
            {
                handleSQLError(e);
            }
        }

        public function removeItem(cls:Class, id:int):void
        {
            var obj:Object = load(cls, id);
            removeObj(obj);
        }

        private function removeObj(obj:Object):void
        {
            var entity:Entity = getEntityForObject(obj);
            removeOneToManyAssociations(obj, entity);

            // Doesn't make sense to support cascade delete on many-to-many associations

            var deleteCommand:DeleteCommand = entity.deleteCommand;
            setKeyParams(deleteCommand, obj, entity);
            deleteCommand.execute();
            if (!entity.hasCompositeKey())
            {
                var id:int = obj[entity.pk.property];
                removeSuperEntity(id, entity.superEntity);
            }
            removeManyToOneAssociations(obj, entity);
        }

        private function removeOneToManyAssociations(obj:Object, entity:Entity):void
        {
            for each(var a:OneToManyAssociation in entity.oneToManyAssociations)
            {
                if (isCascadeDelete(a))
                {
                    var deleteCommand:DeleteCommand = a.deleteCommand;
                    setKeyParams(deleteCommand, obj, entity);
                    deleteCommand.execute();
                }
                // TODO else set the FK to 0 ?
            }
        }

        private function removeSuperEntity(id:int, superEntity:Entity):void
        {
            if (superEntity == null)
                return;

            var deleteCommand:DeleteCommand = superEntity.deleteCommand;
            deleteCommand.setParam(superEntity.pk.property, id);
            deleteCommand.execute();
        }

        private function removeManyToOneAssociations(obj:Object, entity:Entity):void
        {
            for each(var a:Association in entity.manyToOneAssociations)
            {
                var value:Object = obj[a.property];
                if (value && isCascadeDelete(a))
                {
                    removeObj(value);
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

            var value:Object = getCachedValue(entity, getKeyMap(row, entity));
            if (value)
                return value;

            var instance:Object = new entity.cls();
            for each(var f:Field in entity.fields)
            {
                instance[f.property] = row[f.column];
            }

            if (!entity.hasCompositeKey())
            {
                var id:int = row[entity.pk.column];
                loadSuperProperties(instance, id, entity.superEntity);
            }

            loadManyToOneAssociations(instance, row, entity);

            // must be after IDs on instance is set
            setCachedValue(instance, entity);

            loadOneToManyAssociations(instance, row, entity);
            loadManyToManyAssociations(instance, row, entity);

            return instance;
        }

        private function loadSuperProperties(instance:Object, id:int, superEntity:Entity):void
        {
            if (superEntity == null)
                return;

            var superInstance:Object = load(superEntity.cls, id);
            for each(var f:Field in superEntity.fields)
            {
                instance[f.property] = superInstance[f.property];
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
                var value:Object = getCachedValue(associatedEntity, getFkMap(row, associatedEntity));
                if (value)
                {
                    instance[a.property] = value;
                }
                else
                {
                    var keyMap:Object = getKeyMap(row, associatedEntity);
                    if (keyMap)
                    {
                        var items:ArrayCollection = loadItems(associatedEntity.selectCommand, keyMap, associatedEntity);

                        // loadItems may return an empty collection if
                        // a.ownerEntity (fk) has been deleted and the
                        // association was not set to 'cascade-delete'
                        instance[a.property] = (items.length > 0)? items[0] : null;
                    }
                }
            }
        }

        private function loadOneToManyAssociations(instance:Object, row:Object, entity:Entity):void
        {
            for each(var a:OneToManyAssociation in entity.oneToManyAssociations)
            {
                if (a.lazy)
                {
                    instance[a.property] = new LazyList(this, a, getKeyMap(row, entity));
                }
                else
                {
                    instance[a.property] = selectOneToManyAssociation(a, row);
                }
            }
        }

        private function loadManyToManyAssociations(instance:Object, row:Object, entity:Entity):void
        {
            for each(var a:ManyToManyAssociation in entity.manyToManyAssociations)
            {
                if (a.lazy)
                {
                    instance[a.property] = new LazyList(this, a, getKeyMap(row, entity));
                }
                else
                {
                    instance[a.property] = selectManyToManyAssociation(a, row);
                }
            }
        }

        private function selectOneToManyAssociation(a:OneToManyAssociation, row:Object, name:String=null):ArrayCollection
        {
            var selectCommand:SelectCommand = a.selectCommand;
            for each(var key:Key in a.ownerEntity.keys)
            {
                selectCommand.setParam(key.fkProperty, row[key.column]);
            }
            selectCommand.execute();
            return typeArray(selectCommand.result, a.associatedEntity);
        }

        private function selectManyToManyAssociation(a:ManyToManyAssociation, row:Object):ArrayCollection
        {
            var selectCommand:SelectManyToManyCommand = a.selectCommand;
            for each(var key:Key in a.ownerEntity.keys)
            {
                selectCommand.setParam(key.fkProperty, row[key.column]);
            }
            selectCommand.execute();
            return typeArray(selectCommand.result, a.associatedEntity);
        }

    }
}