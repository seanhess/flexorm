package nz.co.codec.flexorm
{
    import flash.data.SQLConnection;
    import flash.events.SQLErrorEvent;
    import flash.events.SQLEvent;
    import flash.filesystem.File;
    import flash.utils.getDefinitionByName;
    import flash.utils.getQualifiedClassName;

    import mx.collections.ArrayCollection;
    import mx.collections.IList;
    import mx.rpc.IResponder;
    import mx.rpc.Responder;
    import mx.utils.UIDUtil;

    import nz.co.codec.flexorm.command.BeginCommand;
    import nz.co.codec.flexorm.command.CommitCommand;
    import nz.co.codec.flexorm.command.DeleteCommand;
    import nz.co.codec.flexorm.command.InsertCommand;
    import nz.co.codec.flexorm.command.RollbackCommand;
    import nz.co.codec.flexorm.command.SelectCommand;
    import nz.co.codec.flexorm.command.UpdateCommand;
    import nz.co.codec.flexorm.criteria.Criteria;
    import nz.co.codec.flexorm.criteria.Sort;
    import nz.co.codec.flexorm.metamodel.AssociatedType;
    import nz.co.codec.flexorm.metamodel.Association;
    import nz.co.codec.flexorm.metamodel.CompositeKey;
    import nz.co.codec.flexorm.metamodel.Entity;
    import nz.co.codec.flexorm.metamodel.Field;
    import nz.co.codec.flexorm.metamodel.IDStrategy;
    import nz.co.codec.flexorm.metamodel.Identity;
    import nz.co.codec.flexorm.metamodel.ManyToManyAssociation;
    import nz.co.codec.flexorm.metamodel.OneToManyAssociation;
    import nz.co.codec.flexorm.metamodel.PersistentEntity;

    public class EntityManagerAsync extends EntityManagerBase implements IEntityManagerAsync
    {
        private static var _instance:EntityManagerAsync;

        private static var localInstantiation:Boolean;

        public static function get instance():EntityManagerAsync
        {
            if (_instance == null)
            {
                localInstantiation = true;
                _instance = new EntityManagerAsync();
                localInstantiation = false;
            }
            return _instance;
        }

        public static function getInstance():EntityManagerAsync
        {
            if (_instance == null)
            {
                localInstantiation = true;
                _instance = new EntityManagerAsync();
                localInstantiation = false;
            }
            return _instance;
        }

        /**
         * EntityManagerAsync is a Singleton.
         */
        public function EntityManagerAsync()
        {
            super();
            if (!localInstantiation)
            {
                throw new Error("EntityManagerAsync is a singleton. Use EntityManagerAsync.instance ");
            }
        }

//        private var running:Boolean;

        private var inTransaction:Boolean;

        private var dbFile:File;

//        private function newEntityManagerAsync():EntityManagerAsync
//        {
//            localInstantiation = true;
//            var instance:EntityManagerAsync = new EntityManagerAsync();
//            localInstantiation = false;
//            instance.entityMap = this.entityMap;
//            instance.opt = this.opt;
//            instance.sqlConnection = this.sqlConnection;
//            return instance;
//        }

        /**
         * Opens an asynchronous connection to the database.
         */
        public function openAsyncConnection(dbFilename:String, responder:IResponder):void
        {
            dbFile = File.applicationStorageDirectory.resolvePath(dbFilename);
            sqlConnection = new SQLConnection();

            var openHandler:Function = function(ev:SQLEvent):void
            {
                sqlConnection.removeEventListener(SQLEvent.OPEN, openHandler);
                sqlConnection.removeEventListener(SQLErrorEvent.ERROR, errorHandler);
                responder.result(ev);
            }
            sqlConnection.addEventListener(SQLEvent.OPEN, openHandler);

            var errorHandler:Function = function(e:SQLErrorEvent):void
            {
                sqlConnection.removeEventListener(SQLEvent.OPEN, openHandler);
                sqlConnection.removeEventListener(SQLErrorEvent.ERROR, errorHandler);
                responder.fault(e);
            }
            sqlConnection.addEventListener(SQLErrorEvent.ERROR, errorHandler);

            sqlConnection.openAsync(dbFile);
        }

        public function closeAsyncConnection(responder:IResponder):void
        {
            if (sqlConnection.connected)
            {
                var closeHandler:Function = function(ev:SQLEvent):void
                {
                    sqlConnection.removeEventListener(SQLEvent.CLOSE, closeHandler);
                    sqlConnection.removeEventListener(SQLErrorEvent.ERROR, errorHandler);
                    responder.result(ev);
                }
                sqlConnection.addEventListener(SQLEvent.CLOSE, closeHandler);

                var errorHandler:Function = function(e:SQLErrorEvent):void
                {
                    sqlConnection.removeEventListener(SQLEvent.CLOSE, closeHandler);
                    sqlConnection.removeEventListener(SQLErrorEvent.ERROR, errorHandler);
                    responder.fault(e);
                }
                sqlConnection.addEventListener(SQLErrorEvent.ERROR, errorHandler);

                sqlConnection.close();
            }
        }

        public function deleteDBFile():void
        {
            dbFile.deleteFile();
        }

        public function startTransaction(responder:IResponder):void
        {
            var beginCommand:BeginCommand = new BeginCommand(sqlConnection);
            beginCommand.responder = responder;
            beginCommand.execute();
            inTransaction = true;
        }

        public function endTransaction(responder:IResponder):void
        {
            var commitCommand:CommitCommand = new CommitCommand(sqlConnection);
            commitCommand.responder = new Responder(

                function(event:EntityEvent):void
                {
                    responder.result(event);
                    inTransaction = false;
                },

                function(error:EntityErrorEvent):void
                {
                    if (sqlConnection.inTransaction)
                    {
                        var rollbackCommand:RollbackCommand = new RollbackCommand(sqlConnection);
                        rollbackCommand.responder = new Responder(

                            function(ev:EntityEvent):void
                            {
                                error.message = "Rollback successful: " + error.message;
                                responder.fault(error);
                            },

                            function(e:EntityErrorEvent):void
                            {
                                trace("Rollback failed!!!");
                                error.message = e.message + ": " + error.message;
                                responder.fault(error);
                            }
                        );
                    }
                    else
                    {
                        responder.fault(error);
                    }
                    inTransaction = false;
                }
            );
        }

        private function getEntityForObject(obj:Object, q:BlockingExecutor):Entity
        {
            var c:Class = (obj is PersistentEntity) ?
                obj.__class :
                Class(getDefinitionByName(getQualifiedClassName(obj)));
            return getEntity(c, q);
        }

        private function getEntity(cls:Class, q:BlockingExecutor):Entity
        {
            var c:Class = (cls is PersistentEntity) ? cls.__class : cls;
            var cn:String = getClassName(c);
            var entity:Entity = entityMap[cn];
            if (entity == null || !entity.initialisationComplete)
            {
                entity = introspector.loadMetadata(c, q);
            }
            return entity;
        }

        private function createBlockingExecutor(responder:IResponder, finalHandler:Function=null):BlockingExecutor
        {
            var q:BlockingExecutor = new BlockingExecutor();
            q.debugLevel = debugLevel;
            q.responder = responder;
            q.finalHandler = finalHandler;
            return q;
        }

        public function findAll(cls:Class, responder:IResponder):void
        {
            var q:BlockingExecutor = createBlockingExecutor(responder, function(data:Object):void
            {
                clearCache();
            });
            var entity:Entity = getEntity(cls, q);
            q.add(entity.selectAllCommand.clone(), function(data:Object):void
            {
                q.data = typeArray(data as Array, entity, q.branchBlocking());
            });
            q.execute();
        }

        public function loadOneToManyAssociation(a:OneToManyAssociation, idMap:Object, responder:IResponder):void
        {
            var branch:BlockingExecutor;
            var q:BlockingExecutor = createBlockingExecutor(responder, function(data:Object):void
            {
                q.data = branch.data;
                clearCache();
            });
            branch = q.branchBlocking();
            loadOneToManyAssociationInternal(a, idMap, branch);
            q.execute();
        }

        private function loadOneToManyAssociationInternal(a:OneToManyAssociation, idMap:Object, q:BlockingExecutor):void
        {
            var items:Array = [];
            q.finalHandler = function(data:Object):void
            {
                if (a.indexed)
                    items.sortOn("index");

                var result:ArrayCollection = new ArrayCollection();
                for each(var it:Object in items)
                {
                    result.addItem(typeObject(it.row, it.associatedEntity, q));
                }
                q.data = result;
            };
            for each(var type:AssociatedType in a.associatedTypes)
            {
                loadAssociatedType(a, items, type, idMap, q);
            }
        }

        private function loadAssociatedType(
            a:OneToManyAssociation,
            items:Array,
            type:AssociatedType,
            idMap:Object,
            q:BlockingExecutor):void
        {
            var associatedEntity:Entity = type.associatedEntity;
            var selectCommand:SelectCommand = type.selectCommand.clone();
            setIdentMapParams(selectCommand, idMap);
            q.add(selectCommand, function(data:Object):void
            {
                if (data)
                {
                    var row:Object;
                    if (associatedEntity.isSuperEntity())
                    {
                        var subtypes:Object = {};
                        for each(row in data)
                        {
                            subtypes[row.entity_type] = null;
                        }
                        for (var subtype:String in subtypes)
                        {
                            loadSubtype(a, items, associatedEntity, subtype, idMap, q);
                        }
                    }
                    else
                    {
                        for each(row in data)
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
            });
        }

        private function loadSubtype(
            a:OneToManyAssociation,
            items:Array,
            associatedEntity:Entity,
            subtype:String,
            idMap:Object,
            q:BlockingExecutor):void
        {
            var subClass:Class = getDefinitionByName(subtype) as Class;
            var subEntity:Entity = getEntity(subClass, q);
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

            q.add(selectSubtypeCommand, function(data:Object):void
            {
                for each(var row:Object in data)
                {
                    items.push(
                    {
                        associatedEntity: subEntity,
                        index           : row[a.indexColumn],
                        row             : row
                    });
                }
            });
        }

        /**
         * Return a list of the associated objects in a many-to-many association
         * using a map of the key values (fkProperty : value).
         */
        public function loadManyToManyAssociation(a:ManyToManyAssociation, idMap:Object, responder:IResponder):void
        {
            var q:BlockingExecutor = createBlockingExecutor(responder);
            var selectCommand:SelectCommand = a.selectCommand.clone();
            setIdentMapParams(selectCommand, idMap);
            q.add(selectCommand, function(data:Object):void
            {
                q.data = typeArray(data as Array, a.associatedEntity, q);
            });
            q.execute();
        }

        public function load(cls:Class, id:int, responder:IResponder):void
        {
            loadItem(cls, id, responder);
        }

        public function loadItem(cls:Class, id:int, responder:IResponder):void
        {
//            if (running)
//            {
//                return newEntityManagerAsync().loadItem(cls, id, responder);
//            }
//            else
//            {
//                running = true;
//            }
            var q:BlockingExecutor = createBlockingExecutor(responder, function(data:Object):void
            {
                clearCache();
//                running = false;
            });
            var entity:Entity = getEntity(cls, q);
            if (entity.hasCompositeKey())
            {
                throw new Error("Entity '" + entity.name + "' has a composite key. " +
                                "Use EntityManagerAsync.loadItemByCompositeKey instead. ");
            }
            loadComplexEntity(entity, getIdentityMap(entity.fkProperty, id), q);
            q.execute();
        }

        private function loadComplexEntity(entity:Entity, idMap:Object, q:BlockingExecutor):void
        {
            var selectCommand:SelectCommand = entity.selectCommand.clone();
            setIdentMapParams(selectCommand, idMap);
            q.add(selectCommand, function(data:Object):void
            {
                if (data)
                {
                    var row:Object = data[0];

                    // Add to cache to avoid reselecting from database
                    q.data = typeObject(row, entity, q);

                    if (entity.isSuperEntity())
                    {
                        var subtype:String = row.entity_type;
                        if (subtype)
                        {
                            var subClass:Class = getDefinitionByName(subtype) as Class;
                            var subEntity:Entity = getEntity(subClass, q);
                            if (subEntity == null)
                                throw new Error("Cannot find entity of type " + subtype);

                            var map:Object = entity.hasCompositeKey() ?
                                getIdentityMapFromRow(row, subEntity) :
                                getIdentityMap(subEntity.fkProperty, idMap[entity.fkProperty]);

                            var value:Object = getCachedValue(subEntity, map);
                            if (value)
                            {
                                q.data = value;
                            }
                            else
                            {
                                loadComplexEntity(subEntity, map, q);
                            }
                        }
                    }
                }
                else
                {
                    q.fault(new EntityErrorEvent(debug("Load of " + entity.name + " failed. ")));
                }
            });
        }

        private function loadEntity(entity:Entity, idMap:Object, q:BlockingExecutor):void
        {
            var selectCommand:SelectCommand = entity.selectCommand.clone();
            setIdentMapParams(selectCommand, idMap);
            q.add(selectCommand, function(data:Object):void
            {
                if (data)
                {
                    q.data = typeObject(data[0], entity, q);
                }
                else
                {
                    q.fault(new EntityErrorEvent(debug("Load of " + entity.name + " failed. ")));
                }
            });
        }

        public function loadItemByCompositeKey(cls:Class, keys:Array, responder:IResponder):void
        {
            var q:BlockingExecutor = createBlockingExecutor(responder, function(data:Object):void
            {
                clearCache();
            });
            var entity:Entity = getEntity(cls, q);
            if (!entity.hasCompositeKey())
            {
                throw new Error("Entity '" + entity.name +
                    "' does not have a composite key. Use EntityManagerAsync.loadItem instead. ");
            }
            var idMap:Object = {};
            for each(var obj:Object in keys)
            {
                var keyEntity:Entity = getEntityForObject(obj, q);

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
            loadComplexEntity(entity, idMap, q);
            q.execute();
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
        public function save(obj:Object, responder:IResponder, opt:Object=null):void
        {
            if (obj == null)
                return;

            if (opt == null)
                opt = {};

            var q:BlockingExecutor = createBlockingExecutor(responder, function(data:Object):void
            {
                clearCache();
            });

            // if not already part of a programmer-defined transaction, then
            // start one to group all cascade 'save-update' operations
            if (!inTransaction)
            {
                q.add(new BeginCommand(sqlConnection));
                saveItem(obj, q, opt);
                q.add(new CommitCommand(sqlConnection));
            }
            else
            {
                saveItem(obj, q, opt);
            }
            q.execute();
        }

        private function saveItem(obj:Object, q:BlockingExecutor, opt:Object):void
        {
            if (obj == null)
                return;

            var entity:Entity = getEntityForObject(obj, q);
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
                q.add(selectCommand, function(data:Object):void
                {
                    if (data)
                    {
                        updateItem(entity.updateCommand.clone(), obj, entity, q, opt);
                    }
                    else
                    {
                        createItem(entity.insertCommand.clone(), obj, entity, q, opt);
                    }
                });
            }
            else
            {
                var id:int = obj[entity.pk.property];
                if (id > 0)
                {
                    updateItem(entity.updateCommand.clone(), obj, entity, q, opt);
                }
                else
                {
                    createItem(entity.insertCommand.clone(), obj, entity, q, opt);
                }
            }
        }

        private function createItem(
            insertCommand:InsertCommand,
            obj:Object,
            entity:Entity,
            q:BlockingExecutor,
            opt:Object):void
        {
            saveManyToOneAssociations(obj, entity, q.branchNonBlocking());
            if (entity.superEntity)
            {
                opt.subInsertCommand = insertCommand;
                opt.entityType = getQualifiedClassName(entity.cls);
                opt.fkProperty = entity.fkProperty;
                createItem(entity.superEntity.insertCommand.clone(), obj, entity.superEntity, q, opt);
            }
            setFieldParams(insertCommand, obj, entity);
            setManyToOneAssociationParams(insertCommand, obj, entity);
            setInsertTimestampParams(insertCommand);

            if (entity.isSuperEntity())
            {
                insertCommand.setParam("entityType", opt.entityType);
            }
            if (opt.syncSupport && !entity.hasCompositeKey())
            {
                insertCommand.setParam("version", 0);
                insertCommand.setParam("serverId", 0);
            }
            insertCommand.setParam("markedForDeletion", false);

            // if this obj is an item of a one-to-many association and matches
            // the specific entity, that is the object of the association, in
            // the entity's inheritance hierarchy...
            if ((opt.a is OneToManyAssociation) && entity.equals(opt.associatedEntity))
            {
                if (opt.hasCompositeKey)
                {
                    setIdentMapParams(insertCommand, opt.idMap);
                }
                else
                {
                    q.addFunction(function(data:Object):void
                    {
                        insertCommand.setParam(opt.a.fkProperty, q.parent.parent.id);
                    });
                }
                if (opt.a.indexed)
                    insertCommand.setParam(opt.a.indexProperty, opt.indexValue);
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
            q.add(insertCommand, function(data:Object):void
            {
                if (!entity.hasCompositeKey() && (entity.superEntity == null))
                {
                    if (IDStrategy.AUTO_INCREMENT == entity.pk.strategy)
                    {
                        id = data;
                        obj[entity.pk.property] = id;
                    }
                    var subInsertCommand:InsertCommand = opt.subInsertCommand;
                    if (subInsertCommand)
                        subInsertCommand.setParam(opt.fkProperty, id);

                    q.id = id;
                    q.label = entity.name;
                }
                q.data = obj;
            });

            // The mtmInsertCommand must be executed after the associated entity
            // has been inserted to maintain referential integrity.
            if ((opt.a is ManyToManyAssociation) && entity.equals(opt.associatedEntity))
            {
                var mtmInsertCommand:InsertCommand = opt.mtmInsertCommand;
                if (opt.hasCompositeKey || (IDStrategy.UID == entity.pk.strategy))
                {
                    setIdentityParams(mtmInsertCommand, obj, entity);
                    setIdentMapParams(mtmInsertCommand, opt.idMap);
                }
                else
                {
                    q.addFunction(function(data:Object):void
                    {
                        mtmInsertCommand.setParam(entity.fkProperty, data);
                        mtmInsertCommand.setParam(opt.a.ownerEntity.fkProperty, q.parent.parent.id);
                    });
                }
                if (opt.a.indexed)
                    mtmInsertCommand.setParam(opt.a.indexProperty, opt.indexValue);

                q.add(mtmInsertCommand);
            }

            var idMap:Object = getIdentityMapFromInstance(obj, entity);
            var executor:NonBlockingExecutor = q.branchNonBlocking();
            saveOneToManyAssociations(obj, entity, idMap, executor);
            for each(var mtm:ManyToManyAssociation in entity.manyToManyAssociations)
            {
                saveManyToManyAssociation(obj, false, mtm, idMap, executor.branchBlocking());
            }
        }

        private function updateItem(
            updateCommand:UpdateCommand,
            obj:Object,
            entity:Entity,
            q:BlockingExecutor,
            opt:Object):void
        {
            saveManyToOneAssociations(obj, entity, q.branchNonBlocking());
            if (entity.superEntity)
                updateItem(entity.superEntity.updateCommand.clone(), obj, entity.superEntity, q, opt);
            setIdentityParams(updateCommand, obj, entity);
            setFieldParams(updateCommand, obj, entity);
            setManyToOneAssociationParams(updateCommand, obj, entity);
            setUpdateTimestampParams(updateCommand);

            if ((opt.a is OneToManyAssociation) && entity.equals(opt.associatedEntity))
            {
                setIdentMapParams(updateCommand, opt.idMap);
                if (opt.a.indexed)
                    updateCommand.setParam(opt.a.indexProperty, opt.indexValue);
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
                            updateCommand.setParam(a.indexProperty, opt.indexValue);
                        }
                        else
                        {
                            updateCommand.setParam(a.indexProperty, 0);
                        }
                    }
                }
            }
            q.add(updateCommand);
            q.data = obj;

            if ((opt.a is ManyToManyAssociation) && entity.equals(opt.associatedEntity))
            {
                var mtmInsertCommand:InsertCommand = opt.mtmInsertCommand;
                setIdentityParams(mtmInsertCommand, obj, entity);
                setIdentMapParams(mtmInsertCommand, opt.idMap);
                if (opt.a.indexed)
                    mtmInsertCommand.setParam(opt.a.indexProperty, opt.indexValue);

                q.add(mtmInsertCommand);
            }

            var idMap:Object = getIdentityMapFromInstance(obj, entity);
            var executor:NonBlockingExecutor = q.branchNonBlocking();
            saveOneToManyAssociations(obj, entity, idMap, executor);
            for each(var mtm:ManyToManyAssociation in entity.manyToManyAssociations)
            {
                saveManyToManyAssociation(obj, true, mtm, idMap, executor.branchBlocking());
            }
        }

        private function saveManyToOneAssociations(obj:Object, entity:Entity, executor:NonBlockingExecutor):void
        {
            for each(var a:Association in entity.manyToOneAssociations)
            {
                var value:Object = obj[a.property];
                if (value && !a.inverse && isCascadeSave(a))
                    saveItem(value, executor.branchBlocking(), {});
            }
        }

        private function saveOneToManyAssociations(obj:Object, entity:Entity, idMap:Object, executor:NonBlockingExecutor):void
        {
            for each (var a:OneToManyAssociation in entity.oneToManyAssociations)
            {
                if (!entity.hasCompositeKey())
                {
                    idMap = getIdentityMap(a.fkProperty, obj[entity.pk.property]);
                }
                var value:IList = obj[a.property];
                if (value && !a.inverse && (!a.lazy || !(value is LazyList) || LazyList(value).loaded) && isCascadeSave(a))
                {
                    for (var i:int = 0; i < value.length; i++)
                    {
                        var item:Object = value.getItemAt(i);
                        var q:BlockingExecutor = executor.branchBlocking();
                        var itemEntity:Entity = getEntityForObject(item, q);
                        var associatedEntity:Entity = a.getAssociatedEntity(itemEntity);
                        if (associatedEntity)
                        {
                            var opt:Object = {
                                a               : a,
                                associatedEntity: associatedEntity,
                                hasCompositeKey : entity.hasCompositeKey(),
                                idMap           : idMap
                            };
                            if (a.indexed)
                                opt.indexValue = i;

                            saveItem(item, q, opt);
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

        private function saveManyToManyAssociation(obj:Object, update:Boolean, a:ManyToManyAssociation, idMap:Object, q:BlockingExecutor):void
        {
            var value:IList = obj[a.property];
            if (value && (!a.lazy || !(value is LazyList) || LazyList(value).loaded))
            {
                var selectExistingCommand:SelectCommand = a.selectManyToManyKeysCommand;
                var hasCompositeKey:Boolean = a.ownerEntity.hasCompositeKey();
                if (hasCompositeKey || update)
                {
                    setIdentMapParams(selectExistingCommand, idMap);
                }
                else
                {
                    q.addFunction(function(data:Object):void
                    {
                        idMap[a.ownerEntity.fkProperty] = q.parent.parent.id;
                        setIdentMapParams(selectExistingCommand, idMap);
                    });
                }
                q.add(selectExistingCommand, function(data:Object):void
                {
                    var existing:Array = [];
                    for each(var row:Object in data)
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
                                    isLinked = true;
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
                                    var updateCommand:UpdateCommand = a.updateCommand.clone();
                                    setIdentMapParams(updateCommand, idMap);
                                    setIdentMapParams(updateCommand, itemIdMap);
                                    updateCommand.setParam(a.indexProperty, i);
                                    q.add(updateCommand);
                                }
                                saveItem(item, q, {});
                            }
                            existing.splice(k, 1);
                        }
                        else
                        {
                            var insertCommand:InsertCommand = a.insertCommand.clone();
                            if (isCascadeSave(a))
                            {
                                // insert link in associationTable after
                                // inserting the associated entity instance
                                var opt:Object = {
                                    a               : a,
                                    associatedEntity: a.associatedEntity,
                                    hasCompositeKey : hasCompositeKey,
                                    idMap           : idMap,
                                    mtmInsertCommand: insertCommand
                                };
                                if (a.indexed)
                                    opt.indexValue = i;

                                saveItem(item, q, opt);
                            }
                            else // just create the link instead
                            {
                                setIdentMapParams(insertCommand, idMap);
                                setIdentMapParams(insertCommand, itemIdMap);
                                if (a.indexed)
                                    insertCommand.setParam(a.indexProperty, i);

                                q.add(insertCommand);
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
                        q.add(deleteCommand);
                    }
                });
            }
        }

        public function markForDeletion(obj:Object, responder:IResponder):void
        {
            var q:BlockingExecutor = createBlockingExecutor(responder);
            var entity:Entity = getEntityForObject(obj, q);
            var markForDeletionCommand:UpdateCommand = entity.markForDeletionCommand;
            setIdentityParams(markForDeletionCommand, obj, entity);
            q.add(markForDeletionCommand);
            q.execute();
        }

        public function removeItem(cls:Class, id:int, responder:IResponder):void
        {
            loadItem(cls, id, new Responder(

                function(ev:EntityEvent):void
                {
                    remove(ev.data, responder);
                },

                function(e:EntityErrorEvent):void
                {
                    trace(e);
                    responder.fault(e);
                }
            ));
        }

        public function remove(obj:Object, responder:IResponder):void
        {
            var q:BlockingExecutor = createBlockingExecutor(responder);

            // if not already part of a programmer-defined transaction,
            // then start one to group all cascade 'delete' operations
            if (!inTransaction)
            {
                q.add(new BeginCommand(sqlConnection));
                removeObject(obj, q);
                q.add(new CommitCommand(sqlConnection));
            }
            else
            {
                removeObject(obj, q);
            }
            q.execute();
        }

        private function removeObject(obj:Object, q:BlockingExecutor):void
        {
            removeEntity(getEntityForObject(obj, q), obj, q);
        }

        private function removeEntity(entity:Entity, obj:Object, q:BlockingExecutor):void
        {
            if (entity == null)
                return;

            removeOneToManyAssociations(entity, obj, q.branchNonBlocking());

            // Doesn't make sense to support 'cascade delete'
            // on many-to-many associations

            var deleteCommand:DeleteCommand = entity.deleteCommand;
            setIdentityParams(deleteCommand, obj, entity);
            q.add(deleteCommand);
            removeEntity(entity.superEntity, obj, q);
            removeManyToOneAssociations(entity, obj, q.branchNonBlocking());
        }

        // TODO I had changed this for performance, but I should revert back
        // to iterating through and removeObject to remove the object graph
        // to effect any cascade delete of associations of the removed object.
        private function removeOneToManyAssociations(entity:Entity, obj:Object, executor:NonBlockingExecutor):void
        {
            for each(var a:OneToManyAssociation in entity.oneToManyAssociations)
            {
                if (isCascadeDelete(a))
                {
                    if (a.multiTyped)
                    {
                        for each(var type:AssociatedType in a.associatedTypes)
                        {
                            removeEntity(type.associatedEntity, obj, executor.branchBlocking());
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
                        executor.add(deleteCommand);
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
                    executor.add(updateCommand);
                }
            }
        }

        private function removeManyToOneAssociations(entity:Entity, obj:Object, executor:NonBlockingExecutor):void
        {
            for each(var a:Association in entity.manyToOneAssociations)
            {
                var value:Object = obj[a.property];
                if (value && isCascadeDelete(a))
                {
                    removeObject(value, executor.branchBlocking());
                }
            }
        }

        private function typeArray(array:Array, entity:Entity, q:BlockingExecutor):ArrayCollection
        {
            var coll:ArrayCollection = new ArrayCollection();
            for each(var row:Object in array)
            {
                coll.addItem(typeObject(row, entity, q));
            }
            return coll;
        }

        private function typeObject(row:Object, entity:Entity, q:BlockingExecutor):Object
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
            loadSuperProperties(instance, row, entity, q);
            var executor:NonBlockingExecutor = q.branchNonBlocking();
            for each(var a:Association in entity.manyToOneAssociations)
            {
                setManyToOneAssociation(instance, row, a, executor.branchBlocking());
            }

            // Must be after keys on instance has been loaded, which includes:
            // - loadManyToOneAssociation to load composite keys, and
            // - loadSuperProperties to load inherited keys.
            if (entity.hasCompositeKey())
            {
                // then must be after many-to-one associations have been loaded
                // to set composite keys
                q.addFunction(function(data:Object):void
                {
                    setListAssociations(instance, row, entity, q.branchNonBlocking());
                });
            }
            else
            {
                setListAssociations(instance, row, entity, executor);
            }

            return instance;
        }

        private function setListAssociations(instance:Object, row:Object, entity:Entity, executor:NonBlockingExecutor):void
        {
            setCachedValue(instance, entity);

            for each(var otm:OneToManyAssociation in entity.oneToManyAssociations)
            {
                setOneToManyAssociation(instance, row, otm, entity, executor.branchBlocking());
            }
            for each(var mtm:ManyToManyAssociation in entity.manyToManyAssociations)
            {
                setManyToManyAssociation(instance, row, mtm, entity, executor.branchBlocking());
            }
        }

        private function loadSuperProperties(
            instance:Object,
            row:Object,
            entity:Entity,
            q:BlockingExecutor):void
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
                setSuperProperties(instance, typeObject(row, superEntity, q), superEntity);
/*
                loadEntity(superEntity, idMap, q.branchBlocking());
//                var branch:BlockingExecutor = q.branchBlocking();
//                loadEntity(superEntity, idMap, branch);
                q.addFunction(function(data:Object):void
                {
                    setSuperProperties(instance, data.data, superEntity);
//                    setSuperProperties(instance, branch.data, superEntity);
                });
*/
            }
            else
            {
                setSuperProperties(instance, superInstance, superEntity);
            }
        }

        private function setSuperProperties(instance:Object, superInstance:Object, superEntity:Entity):void
        {
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
            for each(var otm:Association in superEntity.oneToManyAssociations)
            {
                instance[otm.property] = superInstance[otm.property];
            }
            for each(var mtm:Association in superEntity.manyToManyAssociations)
            {
                instance[mtm.property] = superInstance[mtm.property];
            }
        }

        private function setManyToOneAssociation(
            instance:Object,
            row:Object,
            a:Association,
            q:BlockingExecutor):void
        {
            var associatedEntity:Entity = a.associatedEntity;
            var value:Object = null;
            if (!associatedEntity.isSuperEntity())
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
                    loadComplexEntity(associatedEntity, idMap, q.branchBlocking());
//                    var branch:BlockingExecutor = q.branchBlocking();
//                    loadComplexEntity(associatedEntity, idMap, branch);
                    q.addFunction(function(data:Object):void
                    {
                        instance[a.property] = data.data;
//                        instance[a.property] = branch.data;
                    });
                }
            }
        }

        private function setOneToManyAssociation(
            instance:Object,
            row:Object,
            a:OneToManyAssociation,
            entity:Entity,
            q:BlockingExecutor):void
        {
            var idMap:Object = entity.hasCompositeKey() ?
                getIdentityMapFromRow(row, entity) :
                getIdentityMap(a.fkProperty, row[entity.pk.column]);
            // Lazy Loading not supported using the Asynchronous API yet
//			if (a.lazy)
//			{
//				var lazyList:LazyList = new LazyList(this, a, idMap);
//				var value:ArrayCollection = new ArrayCollection();
//				value.list = lazyList;
//				instance[a.property] = value;
//				lazyList.initialise();
//			}
//			else
//			{

                // TODO optimise if not multiple types

                loadOneToManyAssociationInternal(a, idMap, q.branchBlocking());
//                var branch:BlockingExecutor = q.branchBlocking();
//                loadOneToManyAssociationInternal(a, idMap, branch);
                q.addFunction(function(data:Object):void
                {
                    instance[a.property] = data.data; // TODO check
//                    instance[a.property] = branch.data;
                });
//			}
        }

        private function setManyToManyAssociation(
            instance:Object,
            row:Object,
            a:ManyToManyAssociation,
            entity:Entity,
            q:BlockingExecutor):void
        {
            // Lazy Loading not supported using the Asynchronous API yet
//			if (a.lazy)
//			{
//				var lazyList:LazyList = new LazyList(this, a, getIdentityMapFromRow(row, entity));
//				var value:ArrayCollection = new ArrayCollection();
//				value.list = lazyList;
//				instance[a.property] = value;
//				lazyList.initialise();
//			}
//			else
//			{
                var selectCommand:SelectCommand = a.selectCommand;
                setIdentMapParams(selectCommand, getIdentityMapFromRow(row, entity));
                q.add(selectCommand, function(data:Object):void
                {
                    instance[a.property] = typeArray(data as Array, a.associatedEntity, q);
                });
//			}
        }

        public function createCriteria(cls:Class, responder:IResponder):void
        {
            var q:BlockingExecutor = createBlockingExecutor(responder);
            var entity:Entity = getEntity(cls, q);
            q.addFunction(function(data:Object):void
            {
                q.data = new Criteria(entity);
            });
            q.execute();
        }

        public function fetchCriteria(crit:Criteria, responder:IResponder):void
        {
            var q:BlockingExecutor = createBlockingExecutor(responder, function(data:Object):void
            {
                clearCache();
            });
            var selectCommand:SelectCommand = crit.entity.selectCommand.clone();
            selectCommand.setCriteria(crit);
            q.add(selectCommand, function(data:Object):void
            {
                q.data = typeArray(data as Array, crit.entity, q.branchBlocking());
            });
            q.execute();
        }

        public function fetchCriteriaFirstResult(crit:Criteria, responder:IResponder):void
        {
            var q:BlockingExecutor = createBlockingExecutor(responder, function(data:Object):void
            {
                clearCache();
            });
            var selectCommand:SelectCommand = crit.entity.selectCommand.clone();
            selectCommand.setCriteria(crit);
            q.add(selectCommand, function(data:Object):void
            {
                if (data)
                {
                    var result:Array = data as Array;
                    if (result.length > 0)
                        q.data = typeObject(result[0], crit.entity, q.branchBlocking());
                    else
                        q.data = null;
                }
            });
            q.execute();
        }

        private function debug(message:String):String
        {
            if (debugLevel > 0)
            {
                trace(message);
            }
            return message;
        }

    }
}