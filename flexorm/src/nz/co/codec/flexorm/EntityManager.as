package nz.co.codec.flexorm
{
    import flash.data.SQLConnection;
    import flash.errors.SQLError;
    import flash.filesystem.File;
    import flash.utils.getDefinitionByName;
    import flash.utils.getQualifiedClassName;

    import mx.collections.ArrayCollection;
    import mx.collections.IList;
    import mx.utils.UIDUtil;

    import nz.co.codec.flexorm.command.DeleteCommand;
    import nz.co.codec.flexorm.command.InsertCommand;
    import nz.co.codec.flexorm.command.SelectCommand;
    import nz.co.codec.flexorm.command.SelectMaxRgtCommand;
    import nz.co.codec.flexorm.command.SelectNestedSetTypesCommand;
    import nz.co.codec.flexorm.command.UpdateCommand;
    import nz.co.codec.flexorm.command.UpdateNestedSetsCommand;
    import nz.co.codec.flexorm.command.UpdateNestedSetsLeftBoundaryCommand;
    import nz.co.codec.flexorm.command.UpdateNestedSetsRightBoundaryCommand;
    import nz.co.codec.flexorm.criteria.Criteria;
    import nz.co.codec.flexorm.criteria.Sort;
    import nz.co.codec.flexorm.metamodel.AssociatedType;
    import nz.co.codec.flexorm.metamodel.Association;
    import nz.co.codec.flexorm.metamodel.CompositeKey;
    import nz.co.codec.flexorm.metamodel.Entity;
    import nz.co.codec.flexorm.metamodel.Field;
    import nz.co.codec.flexorm.metamodel.IDStrategy;
    import nz.co.codec.flexorm.metamodel.IHierarchicalObject;
    import nz.co.codec.flexorm.metamodel.Identity;
    import nz.co.codec.flexorm.metamodel.ManyToManyAssociation;
    import nz.co.codec.flexorm.metamodel.OneToManyAssociation;
    import nz.co.codec.flexorm.metamodel.PersistentEntity;
    import nz.co.codec.flexorm.util.Stack;

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

        public static function getInstance():EntityManager
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

        private var nestedSetsLoaded:Boolean;

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
            var command:SelectCommand = entity.selectAllCommand;
            command.execute();
            var result:ArrayCollection = typeArray(command.result, entity);
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
                var selectCommand:SelectCommand = type.selectCommand;
                setIdentMapParams(selectCommand, idMap);
                selectCommand.execute();

                var row:Object;
                if (associatedEntity.isSuperEntity())
                {
                    var subtypes:Object = {};
                    for each(row in selectCommand.result)
                    {
                        subtypes[row.entity_type] = null;
                    }
                    for (var subtype:String in subtypes)
                    {
                        var subClass:Class = getDefinitionByName(subtype) as Class;
                        var subEntity:Entity = getEntity(subClass);
                        var selectSubtypeCommand:SelectCommand = subEntity.selectSubtypeCommand.clone();
                        var ownerEntity:Entity = a.ownerEntity;
                        if (ownerEntity.hasCompositeKey())
                        {
                            for each(var identity:Identity in ownerEntity.identities)
                            {
                                selectSubtypeCommand.addFilter(identity.fkColumn, identity.fkProperty, associatedEntity.table);
                                selectSubtypeCommand.setParam(identity.fkProperty, idMap[identity.fkProperty]);
                            }
                        }
                        else
                        {
                            selectSubtypeCommand.addFilter(a.fkColumn, a.fkProperty, associatedEntity.table);
                            selectSubtypeCommand.setParam(a.fkProperty, idMap[a.fkProperty]);
                        }
                        if (a.indexed)
                            selectSubtypeCommand.addSort(a.indexColumn, Sort.ASC, associatedEntity.table);

                        selectSubtypeCommand.execute();
                        for each(row in selectSubtypeCommand.result)
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
                    for each(row in selectCommand.result)
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

        private function loadNestedSets(entity:Entity, parentEntity:Entity, id:int, lft:int, rgt:int):void
        {
            var row:Object;
            if (lft < 0 || rgt < 1)
            {
                var selectCommand:SelectCommand = entity.selectCommand;
                selectCommand.setParam(entity.fkProperty, id);
                selectCommand.execute();
                var result:Array = selectCommand.result;
                if (result && result.length > 0)
                {
                    row = result[0];
                    lft = row.lft;
                    rgt = row.rgt;
                }
                else return;
            }
            var types:Array = [];
            if (entity.isSuperEntity())
            {
                var selectNestedSetTypesCommand:SelectNestedSetTypesCommand = entity.selectNestedSetTypesCommand;
                selectNestedSetTypesCommand.setParam("lft", lft);
                selectNestedSetTypesCommand.setParam("rgt", rgt);
                selectNestedSetTypesCommand.execute();
                for each(row in selectNestedSetTypesCommand.result)
                {
                    types.push(row.entity_type);
                }
            }
            else
            {
                types.push(getQualifiedClassName(entity.cls));
            }
            var items:Array = [];
            for each(var type:String in types)
            {
                var typeEntity:Entity = getEntity(getDefinitionByName(type) as Class);
                var selectNestedSetsCommand:SelectCommand = typeEntity.selectNestedSetsCommand;
                selectNestedSetsCommand.setParam("lft", lft);
                selectNestedSetsCommand.setParam("rgt", rgt);
                selectNestedSetsCommand.execute();
                for each(row in selectNestedSetsCommand.result)
                {
                    items.push(
                    {
                        entity: typeEntity,
                        lft   : int(row.lft),
                        rgt   : int(row.rgt),
                        row   : row
                    });
                }
            }
            items.sortOn("lft", Array.NUMERIC);
            nestedSetsLoaded = true;

            // type and cache all the nested objects in the branch
            if (items.length > 0)
            {
                var stack:Stack = new Stack();
                stack.push({ entity: parentEntity, lft: lft, rgt: rgt });
                var lastItem:Object = null;
            }
            for each(var it:Object in items)
            {
                if (lastItem && (it.lft < lastItem.rgt))
                    stack.push(lastItem);

                var parentItem:Object = stack.getLastItem();
                if (it.lft > parentItem.rgt)
                {
                    stack.pop();
                    parentItem = stack.getLastItem();
                }
                var parent:Entity = parentItem ? parentItem.entity : null;
                typeObject(it.row, it.entity, null, parent);
                lastItem = it;
            }
            nestedSetsLoaded = false;
        }

        /**
         * Return a list of the associated objects in a many-to-many association
         * using a map of the key values (fkProperty : value).
         */
        public function loadManyToManyAssociation(a:ManyToManyAssociation, idMap:Object):ArrayCollection
        {
            var selectCommand:SelectCommand = a.selectCommand;
            setIdentMapParams(selectCommand, idMap);
            selectCommand.execute();
            return typeArray(selectCommand.result, a.associatedEntity);
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
            var instance:Object = loadEntityWithInheritance(entity, getIdentityMap(entity.fkProperty, id));
            clearCache();
            return instance;
        }

        public function reloadObject(obj:Object):Object
        {
            var entity:Entity = getEntityForObject(obj);
            var instance:Object = loadEntityWithInheritance(entity, getIdentityMapFromInstance(obj, entity));
            clearCache();
            return instance;
        }

        private function loadEntityWithInheritance(entity:Entity, idMap:Object):Object
        {
            var selectCommand:SelectCommand = entity.selectCommand;
            setIdentMapParams(selectCommand, idMap);
            selectCommand.execute();
            var instance:Object = null;
            var result:Array = selectCommand.result;
            if (result && result.length > 0)
            {
                var row:Object = result[0];

                // Add to cache to avoid reselecting from database
                instance = typeObject(row, entity);

                if (entity.isSuperEntity())
                {
                    var subtype:String = row.entity_type;
                    if (subtype)
                    {
                        var subClass:Class = getDefinitionByName(subtype) as Class;
                        var subEntity:Entity = getEntity(subClass);
                        if (subEntity == null)
                            throw new Error("Cannot find entity of type " + subtype);

                        var map:Object = entity.hasCompositeKey() ?
                            getIdentityMapFromRow(row, subEntity) :
                            getIdentityMap(subEntity.fkProperty, idMap[entity.fkProperty]);

                        var value:Object = getCachedValue(subEntity, map);
                        if (value == null)
                            value = loadEntityWithInheritance(subEntity, map);

                        instance = value;
                    }
                }
            }
            return instance;
        }

        private function loadEntity(entity:Entity, idMap:Object):Object
        {
            var selectCommand:SelectCommand = entity.selectCommand;
            setIdentMapParams(selectCommand, idMap);
            selectCommand.execute();
            var result:Array = selectCommand.result;
            return (result && result.length > 0) ? typeObject(result[0], entity) : null;
        }

        /**
         * Added by WDRogers (2008-05-16) to enable loading of objects that are
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
            var instance:Object = loadEntityWithInheritance(entity, idMap);
            clearCache();
            return instance;
        }

        /**
         * Insert or update an object into the database, depending on whether
         * the object is new (determined by an id > 0). Metadata for the object,
         * and all associated objects, will be loaded on a just-in-time basis.
         * The save operation and all cascading saves are enclosed in a
         * transaction to ensure the database is left in a consistent state.
         *
         * Options:
         *
         * Externally set:
         * - ownerClass:Class
         *     Must be set if the client code specifies an indexValue so to
         *     determine the class that owns the indexed list.
         * - indexValue:int
         *     Set by client code when saving an indexed object directly,
         *     instead of saving the object that owns the list and using the
         *     cascade 'save-update' behaviour to set the index property on
         *     each item in the list.
         * - lft:int
         *     Sets the left boundary index when saving a nested set object (a
         *     node in a hierarchy) directly, instead of saving the parent
         *     object and using the cascade 'save-update' behaviour to set the
         *     nested set properties on each child in the list.
         *
         * The lft and ownerClass/indexValue properties are mutually exclusive;
         * ie., the ownerClass and indexValue are unnecessary for a nested set
         * object. The indexed position will be determined from the lft value.
         *
         * The rgt property is unnecessary as it will be set to lft + 1 if the
         * object is new, or to lft + the distance of the object's current rgt
         * value from the current lft value.
         *
         * Internally set:
         * - name:String
         * - a:Association (OneToMany || ManyToMany)
         * - associatedEntity:Entity
         * - idMap:Object
         * - mtmInsertCommand:InsertCommand
         * - indexValue:int
         */
        public function save(obj:Object, opt:Object=null):int
        {
            if (obj == null)
                return 0;

            if (opt == null)
                opt = {};
            opt.rootEval = false;

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

        public function saveHierarchy(obj:Object, opt:Object=null):Object
        {
            if (obj is IHierarchicalObject)
            {
                save(obj, opt);
                return reloadObject(obj);
            }
            else
            {
                throw new Error("Calling saveHierarchy on a non-hierarchical object. ");
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
                var selectCommand:SelectCommand = entity.selectCommand;

                // Validate that each composite key is not null.
                for each(var key:CompositeKey in entity.keys)
                {
                    var value:Object = obj[key.property];
                    if (value == null)
                        throw new Error("Object of type '" + entity.name + "' has a null key. ");
                }
                setIdentityParams(selectCommand, obj, entity);
                selectCommand.execute();
                var result:Array = selectCommand.result;

                // TODO Seems inefficient to load an item in order to determine
                // whether it is new, but this is the only way I can think of
                // for now without interfering with the persistent object.
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
            var insertCommand:InsertCommand = entity.insertCommand;
            if (entity.superEntity)
            {
                if (!entity.hasCompositeKey())
                {
                    opt.subInsertCommand = insertCommand;
                    opt.entityType = getQualifiedClassName(entity.cls);
                    opt.fkProperty = entity.fkProperty;
                }
                createItem(obj, entity.superEntity, opt);
            }
            setFieldParams(insertCommand, obj, entity);
            setManyToOneAssociationParams(insertCommand, obj, entity);
            setInsertTimestampParams(insertCommand);

            if (entity.isSuperEntity())
            {
                insertCommand.setParam("entityType", opt.entityType);
            }
            if (options.syncSupport && !entity.hasCompositeKey())
            {
                insertCommand.setParam("version", 0);
                insertCommand.setParam("serverId", 0);
            }
            insertCommand.setParam("markedForDeletion", false);

            if ((opt.a is OneToManyAssociation) && entity.equals(opt.associatedEntity))
            {
                setIdentMapParams(insertCommand, opt.idMap);
                if (opt.a.hierarchical)
                {
                    openGap(opt.lft, 2, entity);
                    insertCommand.setParam("lft", opt.lft);
                    insertCommand.setParam("rgt", opt.lft + 1);
                    opt.lft++;
                }
                else if (opt.a.indexed)
                    insertCommand.setParam(opt.a.indexProperty, opt.indexValue);
            }
            if (opt.a == null)
            {
                for each(var a:OneToManyAssociation in entity.oneToManyInverseAssociations)
                {
                    if (a.hierarchical)
                    {
                        if (!opt.lft)
                            trace("WARNING new left boundary/position not set on a nested set object. ");

                        opt.lft = opt.lft || 0;
                        openGap(opt.lft, 2, entity);
                        insertCommand.setParam("lft", opt.lft);
                        insertCommand.setParam("rgt", opt.lft + 1);
                        opt.lft++;
                    }
                    else if (a.indexed)
                    {
                         // specified from client code
                        if ((a.ownerEntity.cls == opt.ownerClass) && opt.indexValue)
                        {
                            insertCommand.setParam(a.indexProperty, opt.indexValue);
                        }
                        else
                        {
                            insertCommand.setParam(a.indexProperty, 0);
                        }
                    }
                }
            }
            var id:*;
            if (!entity.hasCompositeKey() && (IDStrategy.UID == entity.pk.strategy))
            {
                id = UIDUtil.createUID();
                insertCommand.setParam(entity.fkProperty, id);
                obj[entity.pk.property] = id;
            }

            insertCommand.execute();

            if (!entity.hasCompositeKey() && (entity.superEntity == null))
            {
                if (IDStrategy.AUTO_INCREMENT == entity.pk.strategy)
                {
                    id = insertCommand.lastInsertRowID;
                    obj[entity.pk.property] = id;
                }
                var subInsertCommand:InsertCommand = opt.subInsertCommand;
                if (subInsertCommand)
                    subInsertCommand.setParam(opt.fkProperty, id);
            }

            // The mtmInsertCommand must be executed after the associated entity
            // has been inserted to maintain referential integrity
            if ((opt.a is ManyToManyAssociation) && entity.equals(opt.associatedEntity))
            {
                var mtmInsertCommand:InsertCommand = opt.mtmInsertCommand;
                setIdentityParams(mtmInsertCommand, obj, entity);
                setIdentMapParams(mtmInsertCommand, opt.idMap);
                if (opt.a.indexed)
                    mtmInsertCommand.setParam(opt.a.indexProperty, opt.indexValue);

                mtmInsertCommand.execute();
            }
            saveOneToManyAssociations(obj, entity, opt);
            saveManyToManyAssociations(obj, entity);
        }

        private function updateItem(obj:Object, entity:Entity, opt:Object):void
        {
            if (obj == null || entity == null)
                return;

            saveManyToOneAssociations(obj, entity);
            updateItem(obj, entity.superEntity, opt);
            var updateCommand:UpdateCommand = entity.updateCommand;
            setIdentityParams(updateCommand, obj, entity);
            setFieldParams(updateCommand, obj, entity);
            setManyToOneAssociationParams(updateCommand, obj, entity);
            setUpdateTimestampParams(updateCommand);

            if ((opt.a is OneToManyAssociation) && entity.equals(opt.associatedEntity))
            {
                setIdentMapParams(updateCommand, opt.idMap);
                if (opt.a.hierarchical)
                {
                    setNestedSetParams(updateCommand, IHierarchicalObject(obj), opt, entity);
                    opt.lft++;
                }
                else if (opt.a.indexed)
                    updateCommand.setParam(opt.a.indexProperty, opt.indexValue);
            }
            if (opt.a == null)
            {
                for each(var a:OneToManyAssociation in entity.oneToManyInverseAssociations)
                {
                    if (a.hierarchical)
                    {
                        var node:IHierarchicalObject = IHierarchicalObject(obj);
                        if (!opt.rootEval)
                        {
                            // Perform once for root node
                            var spread:int = node.rgt - node.lft + 1;
                            closeGap(node.lft, spread, entity);
                            opt.rootLft = node.lft;
                            opt.rootSpread = spread;
                            opt.rootEval = true;
                        }
                        if (!opt.lft)
                            trace("WARNING new left boundary/position not set on a nested set object. ");

                        opt.lft = opt.lft || 0;
                        setNestedSetParams(updateCommand, node, opt, entity);
                        opt.lft++;
                    }
                    else if (a.indexed)
                    {
                         // specified from client code
                        if ((a.ownerEntity.cls == opt.ownerClass) && opt.indexValue)
                        {
                            updateCommand.setParam(a.indexProperty, opt.indexValue);
                        }
                        else
                        {
                            updateCommand.setParam(a.indexProperty, 0);
                        }
                    }
                }
            }
            updateCommand.execute();

            // The mtmInsertCommand must be executed after the associated entity
            // has been inserted to maintain referential integrity.
            if ((opt.a is ManyToManyAssociation) && entity.equals(opt.associatedEntity))
            {
                var mtmInsertCommand:InsertCommand = opt.mtmInsertCommand;
                setIdentityParams(mtmInsertCommand, obj, entity);
                setIdentMapParams(mtmInsertCommand, opt.idMap);
                if (opt.a.indexed)
                    mtmInsertCommand.setParam(opt.a.indexProperty, opt.indexValue);

                mtmInsertCommand.execute();
            }
            saveOneToManyAssociations(obj, entity, opt);
            saveManyToManyAssociations(obj, entity);
        }

        private function setNestedSetParams(
            updateCommand:UpdateCommand,
            node:IHierarchicalObject,
            opt:Object,
            entity:Entity):void
        {
            // if item has moved from outside the bounds of the root node
            if (node.lft < opt.rootLft)
            {
                // close gap there
                var spread:int = node.rgt - node.lft + 1;
                closeGap(node.lft, spread, entity);
                opt.lft = opt.lft - spread;
            }
            if (node.lft >= (opt.rootLft + opt.rootSpread))
            {
                // close gap there
                closeGap(node.lft - opt.rootSpread, (node.rgt - node.lft + 1), entity);
            }
            // open gap here
            openGap(opt.lft, 2, entity);
            updateCommand.setParam("lft", opt.lft);
            updateCommand.setParam("rgt", opt.lft + 1);
        }

        private function moveBranch(node:IHierarchicalObject, newLft:int=-1):void
        {
            var entity:Entity = getEntityForObject(node);
            var selectMaxRgtCommand:SelectMaxRgtCommand = entity.selectMaxRgtCommand;
            selectMaxRgtCommand.execute();

            var maxRgt:int = selectMaxRgtCommand.getMaxRgt();
            if (newLft < 0)
            {
                newLft = maxRgt + 1;
            }
            else if (newLft >= node.lft && newLft <= node.rgt)
                throw new Error("Cannot move a branch to within itself. ");

            var spread:int = node.rgt - node.lft + 1;
            if (newLft < maxRgt)
                openGap(newLft, spread, entity);

            // move branch
            var updateNestedSetsCommand:UpdateNestedSetsCommand = entity.updateNestedSetsCommand;
            updateNestedSetsCommand.setParam("lft", node.lft);
            updateNestedSetsCommand.setParam("rgt", node.rgt);
            updateNestedSetsCommand.setParam("inc", (newLft - node.lft));
            updateNestedSetsCommand.execute();

            closeGap(node.lft, spread, entity);
        }

        private function closeGap(lft:int, spread:int, entity:Entity):void
        {
            var updateRightBoundaryCommand:UpdateNestedSetsRightBoundaryCommand = entity.updateRightBoundaryCommand;
            updateRightBoundaryCommand.setParam("rgt", lft);
            updateRightBoundaryCommand.setParam("inc", -spread);
            updateRightBoundaryCommand.execute();

            var updateLeftBoundaryCommand:UpdateNestedSetsLeftBoundaryCommand = entity.updateLeftBoundaryCommand;
            updateLeftBoundaryCommand.setParam("lft", lft);
            updateLeftBoundaryCommand.setParam("inc", -spread);
            updateLeftBoundaryCommand.execute();
        }

        private function openGap(lft:int, spread:int, entity:Entity):void
        {
            var updateRightBoundaryCommand:UpdateNestedSetsRightBoundaryCommand = entity.updateRightBoundaryCommand;
            updateRightBoundaryCommand.setParam("rgt", lft);
            updateRightBoundaryCommand.setParam("inc", spread);
            updateRightBoundaryCommand.execute();

            var updateLeftBoundaryCommand:UpdateNestedSetsLeftBoundaryCommand = entity.updateLeftBoundaryCommand;
            updateLeftBoundaryCommand.setParam("lft", lft);
            updateLeftBoundaryCommand.setParam("inc", spread);
            updateLeftBoundaryCommand.execute();
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

        private function saveOneToManyAssociations(obj:Object, entity:Entity, opt:Object):void
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

                        var itemEntity:Entity = (OBJECT_TYPE == itemCN) ?
                            getEntityForDynamicObject(item, a.property) :
                            getEntity(itemClass);

                        var associatedEntity:Entity = a.getAssociatedEntity(itemEntity);
                        if (associatedEntity)
                        {
                            opt.a = a;
                            opt.idMap = idMap;
                            opt.associatedEntity = associatedEntity;
                            if (a.indexed && !a.hierarchical)
                                opt.indexValue = i;

                            if (associatedEntity.isDynamicObject())
                                opt.name = a.property;

                            saveItem(item, opt);
                            if (a.hierarchical)
                                opt.lft++;
                        }
                        else
                        {
                            throw new Error("Attempting to save a collection " +
                                            "item of a type not specified in " +
                                            "the one-to-many association. ");
                        }
                    }
                    opt.a = null;
                    opt.idMap = null;
                    opt.associationEntity = null;
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

                    var selectExistingCommand:SelectCommand = a.selectManyToManyKeysCommand;
                    setIdentityParams(selectExistingCommand, obj, entity);
                    selectExistingCommand.execute();

                    var existing:Array = [];
                    for each(var row:Object in selectExistingCommand.result)
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
                                    var updateCommand:UpdateCommand = a.updateCommand;
                                    setIdentMapParams(updateCommand, idMap);
                                    setIdentMapParams(updateCommand, itemIdMap);
                                    updateCommand.setParam(a.indexProperty, i);
                                    updateCommand.execute();
                                }
                                saveItem(item, {});
                            }
                            existing.splice(k, 1);
                        }
                        else
                        {
                            var insertCommand:InsertCommand = a.insertCommand;
                            if (isCascadeSave(a))
                            {
                                // insert link in associationTable after
                                // inserting the associated entity instance
                                var opt:Object = {
                                    a               : a,
                                    associatedEntity: a.associatedEntity,
                                    idMap           : idMap,
                                    mtmInsertCommand: insertCommand
                                }
                                if (a.indexed)
                                    opt.indexValue = i;

                                saveItem(item, opt);
                            }
                            else // just create the link instead
                            {
                                setIdentMapParams(insertCommand, idMap);
                                setIdentMapParams(insertCommand, itemIdMap);
                                if (a.indexed)
                                    insertCommand.setParam(a.indexProperty, i);

                                insertCommand.execute();
                            }
                        }
                    }
                    // for each pre index left
                    for each(map in existing)
                    {
                        // delete link from associationTable
                        var deleteCommand:DeleteCommand = a.deleteCommand;
                        setIdentMapParams(deleteCommand, idMap);
                        setIdentMapParams(deleteCommand, map);
                        deleteCommand.execute();
                    }
                }
            }
        }

        public function markForDeletion(obj:Object):void
        {
            var entity:Entity = getEntityForObject(obj);
            var markForDeletionCommand:UpdateCommand = entity.markForDeletionCommand;
            setIdentityParams(markForDeletionCommand, obj, entity);
            markForDeletionCommand.execute();
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

            var deleteCommand:DeleteCommand = entity.deleteCommand;
            setIdentityParams(deleteCommand, obj, entity);
            deleteCommand.execute();
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
                        var deleteCommand:DeleteCommand = a.deleteCommand;
                        if (entity.hasCompositeKey())
                        {
                            setIdentityParams(deleteCommand, obj, entity);
                        }
                        else
                        {
                            deleteCommand.setParam(a.fkProperty, obj[entity.pk.property]);
                        }
                        deleteCommand.execute();
                    }
                }
                else // set the FK to 0
                {
                    var updateCommand:UpdateCommand = a.updateFKAfterDeleteCommand;
                    if (entity.hasCompositeKey())
                    {
                        setIdentityParams(updateCommand, obj, entity);
                    }
                    else
                    {
                        updateCommand.setParam(a.fkProperty, obj[entity.pk.property]);
                    }
                    updateCommand.execute();

                    if (a.hierarchical) // make any children root nodes
                    {
                        // moves children to far right as root nodes by default
                        if (obj is IHierarchicalObject)
                            moveBranch(IHierarchicalObject(obj));
                    }
                }
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

        private function typeObject(row:Object, entity:Entity, target:Entity=null, parent:Entity=null):Object
        {
            if (row == null)
                return null;

            if (target == null)
                target = entity;

            var value:Object = getCachedValue(entity, getIdentityMapFromRow(row, entity));
            if (value)
                return value;

            var instance:Object = new entity.cls();
            if (entity.hierarchical)
            {
                var node:IHierarchicalObject = IHierarchicalObject(instance);
                node.lft = row.lft;
                node.rgt = row.rgt;
            }
            for each(var f:Field in entity.fields)
            {
                instance[f.property] = row[f.column];
            }
            setSuperProperties(instance, row, entity, target, parent);
            setManyToOneAssociations(instance, row, entity, target, parent);

            // Must be after keys on instance has been loaded, which includes:
            // # loadManyToOneAssociations to load composite keys, and
            // # loadSuperProperties to load inherited keys.
            setCachedValue(instance, entity);

            setOneToManyAssociations(instance, row, entity);
            setManyToManyAssociations(instance, row, entity);

            if (entity.hierarchical && entity.equals(target))
            {
                // If the nested set select is ordered by 'lft' then parents
                // should always be processed before their children.
                var parentInstance:Object = instance[entity.parentProperty];
                if (parentInstance)
                {
                    // Recursive (hierarchical) entities can't have composite keys.
                    getCachedChildren(parentInstance[entity.pk.property]).addItem(instance);
                }
            }

            return instance;
        }

        private function setSuperProperties(instance:Object, row:Object, entity:Entity, target:Entity, parent:Entity):void
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
                // No need to select since I have the super entity's columns
                // from the join in the original select. I just need to call
                // typeObject to load any associations of the super entity.
                superInstance = typeObject(row, superEntity, target, parent);
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

        private function setManyToOneAssociations(instance:Object, row:Object, entity:Entity, target:Entity, parent:Entity):void
        {
            for each(var a:Association in entity.manyToOneAssociations)
            {
                var associatedEntity:Entity = a.associatedEntity;
                var value:Object = null;

                // Skip lookup of super instances in the cache, otherwise the
                // loading of subtype associations will get bypassed, unless
                // the association is hierarchical, in which case the whole
                // hierarchy has already been loaded.
                if (a.hierarchical && parent)
                {
                    value = getCachedValue(parent, getIdentityMap(parent.fkProperty, row[a.fkColumn]));
                }
                else if (entity.equals(target))
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
                        instance[a.property] = loadEntityWithInheritance(associatedEntity, idMap);
                    }
                }
            }
        }

        private function setOneToManyAssociations(instance:Object, row:Object, entity:Entity):void
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
                    if (a.hierarchical)
                    {
                        var parentId:int = row[entity.pk.column];
                        if (!nestedSetsLoaded) // one-time event for root
                        {
                            for each(var type:AssociatedType in a.associatedTypes)
                            {
                                var parentEntity:Entity = entity.isSuperEntity() ?
                                    getEntity(getDefinitionByName(row.entity_type) as Class) :
                                    entity;
                                loadNestedSets(type.associatedEntity, parentEntity, parentId, row.lft, row.rgt);
                            }
                        }
                        // Recursive (hierarchical) entities can't have composite keys.
                        instance[a.property] = getCachedChildren(parentId);
                    }
                    else
                    instance[a.property] = loadOneToManyAssociationInternal(a, idMap);
                }
            }
        }

        private function setManyToManyAssociations(instance:Object, row:Object, entity:Entity):void
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
            var selectCommand:SelectCommand = a.selectCommand;
            setIdentMapParams(selectCommand, getIdentityMapFromRow(row, a.ownerEntity));
            selectCommand.execute();
            return typeArray(selectCommand.result, a.associatedEntity);
        }

        public function createCriteria(cls:Class):Criteria
        {
            return new Criteria(getEntity(cls));
        }

        public function fetchCriteria(crit:Criteria):ArrayCollection
        {
            var selectCommand:SelectCommand = crit.entity.selectCommand.clone();
            selectCommand.setCriteria(crit);
            selectCommand.execute();
            var result:ArrayCollection = typeArray(selectCommand.result, crit.entity);
            clearCache();
            return result;
        }

        public function fetchCriteriaFirstResult(crit:Criteria):Object
        {
            var result:ArrayCollection = fetchCriteria(crit);
            return (result.length > 0) ? result[0] : null;
        }

        /**
         * Returns metadata for a persistent object. If not already defined,
         * then uses the EntityIntrospector to load metadata using the
         * persistent object's annotations.
         */
        private function getEntity(cls:Class):Entity
        {
            var c:Class = (cls is PersistentEntity) ? cls.__class : cls;
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