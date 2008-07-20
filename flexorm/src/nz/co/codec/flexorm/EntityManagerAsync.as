package nz.co.codec.flexorm
{
    import flash.data.SQLConnection;
    import flash.events.SQLErrorEvent;
    import flash.events.SQLEvent;
    import flash.filesystem.File;
    import flash.utils.getDefinitionByName;
    import flash.utils.getQualifiedClassName;

    import mx.collections.ArrayCollection;
    import mx.rpc.IResponder;
    import mx.rpc.Responder;

    import nz.co.codec.flexorm.command.BeginCommand;
    import nz.co.codec.flexorm.command.CommitCommand;
    import nz.co.codec.flexorm.command.DeleteCommand;
    import nz.co.codec.flexorm.command.InsertCommand;
    import nz.co.codec.flexorm.command.MarkForDeletionCommand;
    import nz.co.codec.flexorm.command.RollbackCommand;
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

    public class EntityManagerAsync extends EntityManagerBase implements IEntityManagerAsync
    {
        private static var _instance:EntityManagerAsync;

        private static var localInstantiation:Boolean = false;

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

        private var inTransaction:Boolean = false;

        public function EntityManagerAsync()
        {
            super();
            if (!localInstantiation)
            {
                throw new Error("EntityManagerAsync is a singleton. Use EntityManagerAsync.instance");
            }
        }

        public function openAsyncConnection(dbFilename:String, responder:IResponder):void
        {
            var dbFile:File = File.applicationStorageDirectory.resolvePath(dbFilename);
            _sqlConnection = new SQLConnection();

            var openHandler:Function = function(event:SQLEvent):void
            {
                _sqlConnection.removeEventListener(SQLEvent.OPEN, openHandler);
                _sqlConnection.removeEventListener(SQLErrorEvent.ERROR, openHandler);
                responder.result(event);
            }
            _sqlConnection.addEventListener(SQLEvent.OPEN, openHandler);

            var errorHandler:Function = function(error:SQLErrorEvent):void
            {
                _sqlConnection.removeEventListener(SQLEvent.OPEN, errorHandler);
                _sqlConnection.removeEventListener(SQLErrorEvent.ERROR, errorHandler);
                responder.fault(error);
            }
            _sqlConnection.addEventListener(SQLErrorEvent.ERROR, errorHandler);

            _sqlConnection.openAsync(dbFile);
            introspector = null;
        }

        override public function get sqlConnection():SQLConnection
        {
            return _sqlConnection;
        }

        public function startTransaction(responder:IResponder):void
        {
            var beginCommand:BeginCommand = new BeginCommand(sqlConnection);
            beginCommand.setResponder(responder);
            beginCommand.execute();
            inTransaction = true;
        }

        public function endTransaction(responder:IResponder):void
        {
            var commitCommand:CommitCommand = new CommitCommand(sqlConnection);
            commitCommand.setResponder(new Responder(
                function(event:EntityEvent):void
                {
                    responder.result(event);
                    inTransaction = false;
                },
                function(error:EntityError):void
                {
                    if (sqlConnection.inTransaction)
                    {
                        var rollbackCommand:RollbackCommand = new RollbackCommand(sqlConnection);
                        rollbackCommand.setResponder(new Responder(
                            function(ev:EntityEvent):void
                            {
                                error.message = "Rollback successful: " + error.message;
                                responder.fault(error);
                            },
                            function(e:EntityError):void
                            {
                                trace("Rollback failed!!!");
                                error.message = e.message + ": " + error.message;
                                responder.fault(error);
                            }
                        ));
                    }
                    else
                    {
                        responder.fault(error);
                    }
                    inTransaction = false;
                }
            ));
        }

        public function findAll(cls:Class, responder:IResponder):void
        {
            var c:Class = (cls is PersistentEntity)? cls.myClass : cls;
            var cn:String = getClassName(c);
            var entity:Entity = map[cn];

            var q:BlockingExecutor = new BlockingExecutor();
            q.setResponder(responder);
            if (entity == null || !entity.initialisationComplete)
            {
                entity = introspector.loadMetadata(c, null, q);
            }
            q.addCommand(entity.findAllCommand.clone());
            q.addFunction(function(data:Object):void
            {
                if (data)
                {
                    q.response = typeArray(data as Array, entity, q);

                    // Causing an issue when fetching graphs
                    // Operation cannot be performed while SQLStatement.executing is true.
//                    q.response = typeArray(data as Array, entity, q.branchNonBlocking());
                }
                else
                {
                    debug("Find all of " + entity.name + " failed");
                }
            });
            q.execute();
        }

        public function loadOneToManyAssociation(a:OneToManyAssociation, id:int, responder:IResponder):void
        {
            var c:Class = a.associatedEntity.cls;
            var cn:String = getClassName(c);
            var entity:Entity = map[cn];

            var q:BlockingExecutor = new BlockingExecutor();
            q.setResponder(responder);
            if (entity == null || !entity.initialisationComplete)
            {
                entity = introspector.loadMetadata(c, null, q);
            }
            var selectCommand:SelectCommand = a.selectCommand.clone();
            selectCommand.setParam(a.ownerEntity.fkProperty, id);
            q.addCommand(selectCommand);
            q.addFunction(function(data:Object):void
            {
                if (data)
                {
                    q.response = typeArray(data as Array, entity, q);
                }
                else
                {
                    debug("Select one-to-many of " +
                          a.associatedEntity.name + " with " +
                          a.ownerEntity.fkProperty + ": " + id + " failed");
                }
            });
            q.execute();

        }

        public function loadManyToManyAssociation(a:ManyToManyAssociation, id:int, responder:IResponder):void
        {
            var c:Class = a.associatedEntity.cls;
            var cn:String = getClassName(c);
            var entity:Entity = map[cn];

            var q:BlockingExecutor = new BlockingExecutor();
            q.setResponder(responder);
            if (entity == null || !entity.initialisationComplete)
            {
                entity = introspector.loadMetadata(c, null, q);
            }
            var selectCommand:SelectManyToManyCommand = a.selectCommand.clone();
            selectCommand.setParam(a.ownerEntity.fkProperty, id);
            q.addCommand(selectCommand);
            q.addFunction(function(data:Object):void
            {
                if (data)
                {
                    q.response = typeArray(data as Array, entity, q);
                }
                else
                {
                    debug("Select many-to-many of " + a.associationTable +
                          " with " + a.ownerEntity.fkProperty + ": " + id +
                          " failed");
                }
            });
            q.execute();

        }

        public function loadItem(cls:Class, id:int, responder:IResponder):void
        {
            var c:Class = (cls is PersistentEntity)? cls.myClass : cls;
            var cn:String = getClassName(c);
            var entity:Entity = map[cn];

            var q:BlockingExecutor = new BlockingExecutor();
            q.setResponder(responder);
            if (entity == null || !entity.initialisationComplete)
            {
                entity = introspector.loadMetadata(c, null, q);
            }
            if (entity.hasCompositeKey())
            {
                throw new Error("Entity '" + entity.name +
                    "' has a composite key. Use EntityManagerAsync.loadItemByCompositeKey instead.");
            }

            var selectCommand:SelectCommand = entity.selectCommand.clone();
            selectCommand.setParam(entity.pk.property, id);
            q.addCommand(selectCommand);
            q.addFunction(function(data:Object):void
            {
                if (data)
                {
                    q.response = typeObject(data[0], entity, q);
                }
                else
                {
                    q.fault(new EntityError(debug("Load of " + entity.name +
                        " with id: " + id + " failed")));
                }
            });
            q.execute();
        }

        public function load(cls:Class, id:int, responder:IResponder):void
        {
            loadItem(cls, id, responder);
        }

        public function loadItemByCompositeKey(cls:Class, compositeKeys:Array, responder:IResponder):void
        {
            var c:Class = (cls is PersistentEntity)? cls.myClass : cls;
            var cn:String = getClassName(c);
            var entity:Entity = map[cn];

            var q:BlockingExecutor = new BlockingExecutor("loadItemByCompositeKey", debugLevel);
            q.setResponder(responder);
            if (entity == null || !entity.initialisationComplete)
            {
                entity = introspector.loadMetadata(c, null, q);
            }
            if (!entity.hasCompositeKey())
            {
                throw new Error("Entity '" + entity.name +
                    "' does not have a composite key. Use EntityManagerAsync.load instead.");
            }

            var selectCommand:SelectCommand = entity.selectCommand;
            for each(var obj:Object in compositeKeys)
            {
                var keyClass:Class = (obj is PersistentEntity)?
                    obj.myClass :
                    Class(getDefinitionByName(getQualifiedClassName(obj)));
                var keyCN:String = getClassName(keyClass);
                var keyEntity:Entity = map[keyCN];
                if (keyEntity == null || !keyEntity.initialisationComplete)
                {
                    keyEntity = introspector.loadMetadata(c, null, q);
                }
                var key:Key;

                // validate if key is a specified identifier for entity
                var match:Boolean = false;
                for each(var identity:CompositeIdentity in entity.identities)
                {
                    if (identity.associatedEntity.name == keyEntity.name)
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
                    trace("Key of type '" + keyEntity.name +
                            "' not specified as an identifier for '" +
                            entity.name + "'.");

                    for each(var a:Association in entity.manyToOneAssociations)
                    {
                        if (a.associatedEntity.name == keyEntity.name)
                        {
                            trace("Key type '" + keyEntity.name +
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
                    throw new Error("Invalid key of type '" + keyEntity.name + "' specified.");
            }

            q.addCommand(selectCommand, "select " + entity.name);
            q.addFunction(function(data:Object):void
            {
                if (data)
                {
                    q.response = typeObject(data[0], entity, q);
                }
                else
                {
                    q.fault(new EntityError(debug("Load of " + entity.name +
                        " with composite keys failed")));
                }
            }, "type object");
            q.execute();

        }

        public function save(obj:Object, responder:IResponder):void
        {
            var q:BlockingExecutor = new BlockingExecutor();
            q.setResponder(responder);

            // if not already part of a programmer-defined transaction, then
            // start one to group all cascade 'save-update' operations
            if (!inTransaction)
            {
                q.addCommand(new BeginCommand(sqlConnection));
                saveItem(obj, q);
                q.addCommand(new CommitCommand(sqlConnection));
            }
            else
            {
                saveItem(obj, q);
            }
            q.execute();
        }

        private function saveItem(
            obj:Object,
            q:BlockingExecutor,
            foreignKeys:Array=null,
            mtmInsertCommand:InsertCommand=null,
            idx:Object=null):void
        {
            if (obj == null)
                return;

            var c:Class = getClass(obj);
            var cn:String = getClassName(c);
            var entity:Entity = map[cn];
            if (entity == null || !entity.initialisationComplete)
            {
                entity = introspector.loadMetadata(c, null, q);
            }

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
                q.addCommand(selectCommand);
                q.addFunction(function(data:Object):void
                {
                    if (data)
                    {
                        updateItem(entity.updateCommand.clone(), obj, entity, q, foreignKeys, mtmInsertCommand, idx);
                    }
                    else
                    {
                        createItem(entity.insertCommand.clone(), obj, entity, q, foreignKeys, mtmInsertCommand, idx);
                    }
                });
            }
            else
            {
                var id:int = obj[entity.pk.property];
                if (id > 0)
                {
                    updateItem(entity.updateCommand.clone(), obj, entity, q, foreignKeys, mtmInsertCommand, idx);
                }
                else
                {
                    createItem(entity.insertCommand.clone(), obj, entity, q, foreignKeys, mtmInsertCommand, idx);
                }
            }
        }

        private function createItem(
            insertCommand:InsertCommand,
            obj:Object,
            entity:Entity,
            q:BlockingExecutor,
            foreignKeys:Array,
            mtmInsertCommand:InsertCommand,
            idx:Object):void
        {
            saveManyToOneAssociations(obj, entity, q.branchNonBlocking());
            createSuperEntity(insertCommand, obj, entity.superEntity, q);
            setInsertTimestampParams(insertCommand);

            if (syncSupport && !entity.hasCompositeKey())
            {
                insertCommand.setParam("serverId", 0);
            }
            insertCommand.setParam("markedForDeletion", false);
            setFieldParams(insertCommand, obj, entity);
            setManyToOneAssociationParams(insertCommand, obj, entity);

            if (foreignKeys && !mtmInsertCommand)
            {
                if (foreignKeys.length == 1)
                {
                    q.addFunction(function(data:Object):void
                    {
                        insertCommand.setParam(foreignKeys[0].property, q.parent.parent.id);
                    });
                }
                else
                {
                    setForeignKeyParams(insertCommand, foreignKeys);
                }
                if (idx)
                {
                    insertCommand.setParam(idx.property, idx.value);
                }
            }
            q.addCommand(insertCommand);
            q.addFunction(function(data:Object):void
            {
                if (!entity.hasCompositeKey() && !entity.superEntity)
                {
                    obj[entity.pk.property] = data;
                }
                q.id = data as int;
                q.response = obj;
            });
            if (foreignKeys && mtmInsertCommand)
            {
                if (foreignKeys.length == 1)
                {
                    q.addFunction(function(data:Object):void
                    {
                        mtmInsertCommand.setParam(entity.fkProperty, data);
                        mtmInsertCommand.setParam(foreignKeys[0].property, q.parent.parent.parent.parent.id);
                    });
                }
                else
                {
                    setFkParams(mtmInsertCommand, obj, entity);
                    setForeignKeyParams(mtmInsertCommand, foreignKeys);
                }
                if (idx)
                {
                    mtmInsertCommand.setParam(idx.property, idx.value);
                }
                q.addCommand(mtmInsertCommand);
            }
            var executor:NonBlockingExecutor = q.branchNonBlocking();
            saveOneToManyAssociations(obj, entity, executor);
            for each(var a:ManyToManyAssociation in entity.manyToManyAssociations)
            {
                saveManyToManyAssociation(obj, a, executor.branchBlocking());
            }
        }

        private function updateItem(
            updateCommand:UpdateCommand,
            obj:Object,
            entity:Entity,
            q:BlockingExecutor,
            foreignKeys:Array,
            mtmInsertCommand:InsertCommand,
            idx:Object):void
        {
            saveManyToOneAssociations(obj, entity, q.branchNonBlocking());
            updateSuperEntity(updateCommand, obj, entity.superEntity, q);
            setKeyParams(updateCommand, obj, entity);
            setUpdateTimestampParams(updateCommand);
            setFieldParams(updateCommand, obj, entity);
            setManyToOneAssociationParams(updateCommand, obj, entity);

            if (foreignKeys && mtmInsertCommand == null)
            {
                setForeignKeyParams(updateCommand, foreignKeys);
                if (idx)
                {
                    updateCommand.setParam(idx.property, idx.value);
                }
            }
            q.addCommand(updateCommand);
            q.response = obj;
            if (foreignKeys && mtmInsertCommand)
            {
                setFkParams(mtmInsertCommand, obj, entity);
                setForeignKeyParams(mtmInsertCommand, foreignKeys);
                if (idx)
                {
                    mtmInsertCommand.setParam(idx.property, idx.value);
                }
                q.addCommand(mtmInsertCommand);
            }
            var executor:NonBlockingExecutor = q.branchNonBlocking();
            saveOneToManyAssociations(obj, entity, executor);
            for each(var a:ManyToManyAssociation in entity.manyToManyAssociations)
            {
                saveManyToManyAssociation(obj, a, executor.branchBlocking());
            }
        }

        private function saveManyToOneAssociations(obj:Object, entity:Entity, executor:NonBlockingExecutor):void
        {
            for each(var a:Association in entity.manyToOneAssociations)
            {
                var value:Object = obj[a.property];
                if (value && !a.inverse && isCascadeSave(a))
                {
                    saveItem(value, executor.branchBlocking());
                }
            }
        }

        private function createSuperEntity(
            insertCommand:InsertCommand,
            obj:Object,
            superEntity:Entity,
            q:BlockingExecutor):void
        {
            if (superEntity == null)
                return;

            saveManyToOneAssociations(obj, superEntity, q.branchNonBlocking());
            var superInsertCommand:InsertCommand = superEntity.insertCommand;

            if (syncSupport && !superEntity.hasCompositeKey())
            {
                superInsertCommand.setParam("serverId", 0);
            }
            superInsertCommand.setParam("markedForDeletion", false);

            setFieldParams(superInsertCommand, obj, superEntity);
            setManyToOneAssociationParams(superInsertCommand, obj, superEntity);
            setInsertTimestampParams(superInsertCommand);
            q.addCommand(superInsertCommand);
            q.addFunction(function(data:Object):void
            {
                var id:int = int(data);
                if (id > 0)
                {
                    var pk:PrimaryIdentity = superEntity.pk;
                    insertCommand.setParam(pk.property, id);
                    obj[pk.property] = id;
                }
                else
                {
                    q.fault(new EntityError(debug("Insert of '" + superEntity.className + "' failed")));
                }
            });
        }

        private function updateSuperEntity(
            updateCommand:UpdateCommand,
            obj:Object,
            superEntity:Entity,
            q:BlockingExecutor):void
        {
            if (superEntity == null)
                return;

            saveManyToOneAssociations(obj, superEntity, q.branchNonBlocking());
            var superUpdateCommand:UpdateCommand = superEntity.updateCommand;
            setFieldParams(superUpdateCommand, obj, superEntity);
            if (!superEntity.hasCompositeKey())
            {
                var pk:PrimaryIdentity = superEntity.pk;
                superUpdateCommand.setParam(pk.property, obj[pk.property]);
            }
            setManyToOneAssociationParams(superUpdateCommand, obj, superEntity);
            setUpdateTimestampParams(superUpdateCommand);
            q.addCommand(superUpdateCommand);
        }

        private function saveOneToManyAssociations(obj:Object, entity:Entity, executor:NonBlockingExecutor):void
        {
            var foreignKeys:Array;
            if (entity.hasCompositeKey())
            {
                foreignKeys = getForeignKeys(obj, entity);
            }
            for each (var a:OneToManyAssociation in entity.oneToManyAssociations)
            {
                var value:Object = obj[a.property];
                if (value && !a.inverse && (!a.lazy || !(value is LazyList) || LazyList(value).loaded) && isCascadeSave(a))
                {
                    if (!entity.hasCompositeKey())
                    {
                        foreignKeys = [{ property: a.fkProperty, id: obj[entity.pk.property] }];
                    }
                    for (var i:int = 0; i < value.length; i++)
                    {
                        if (a.indexed)
                        {
                            saveItem(value.getItemAt(i), executor.branchBlocking(), foreignKeys, null, { property: a.indexProperty, value: i });
                        }
                        else
                        {
                            saveItem(value.getItemAt(i), executor.branchBlocking(), foreignKeys);
                        }
                    }
                }
            }
        }

        private function saveManyToManyAssociation(obj:Object, a:ManyToManyAssociation, q:BlockingExecutor):void
        {
            var value:Object = obj[a.property];
            if (value && (!a.lazy || !(value is LazyList) || LazyList(value).loaded))
            {
                var foreignKeys:Array = getForeignKeys(obj, a.ownerEntity);

                var selectIndicesCommand:SelectManyToManyIndicesCommand = a.selectIndicesCommand;
                q.addFunction(function(data:Object):void
                {
                    setFkParams(selectIndicesCommand, obj, a.ownerEntity);
                });
                q.addCommand(selectIndicesCommand);
                q.addFunction(function(data:Object):void
                {
                    var key:Key;
                    var preIndices:Array = [];
                    for each(var row:Object in data)
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
                                    isLinked = true;
                                    break;
                                }
                            }
                            if (isLinked)
                                break;
                            k++;
                        }

                        if (isLinked) // then no need to update associationTable
                        {
                            if (isCascadeSave(a))
                            {
                                if (a.indexed)
                                {
                                    var updateCommand:UpdateCommand = a.updateCommand.clone();
                                    setFkParams(updateCommand, obj, a.ownerEntity);
                                    setFkParams(updateCommand, item, a.associatedEntity);
                                    updateCommand.setParam(a.indexProperty, i);
                                    q.addCommand(updateCommand);
                                }
                                saveItem(item, q);
                            }
                            preIndices.splice(idx, 1);
                        }
                        else
                        {
                            var insertCommand:InsertCommand = a.insertCommand.clone();
                            if (isCascadeSave(a))
                            {
                                // insert link in associationTable
                                if (a.indexed)
                                {
                                    saveItem(item, q, foreignKeys, insertCommand, { property: a.indexProperty, value: i });
                                }
                                else
                                {
                                    saveItem(item, q, foreignKeys, insertCommand);
                                }
                            }
                            else // just create the link instead
                            {
                                setFkParams(insertCommand, obj, a.ownerEntity);
                                setFkParams(insertCommand, item, a.associatedEntity);
                                if (a.indexed)
                                {
                                    insertCommand.setParam(a.indexProperty, i);
                                }
                                q.addCommand(insertCommand);
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
                        setFkParams(deleteCommand, obj, a.ownerEntity);
                        q.addCommand(deleteCommand);
                    }
                });
            }
        }

        public function markForDeletion(obj:Object, responder:IResponder):void
        {
            var q:BlockingExecutor = new BlockingExecutor();
            q.setResponder(responder);
            var c:Class = getClass(obj);
            var cn:String = getClassName(c);
            var entity:Entity = map[cn];
            if (entity == null || !entity.initialisationComplete)
            {
                entity = introspector.loadMetadata(c, null, q);
            }
            var markForDeletionCommand:MarkForDeletionCommand = entity.markForDeletionCommand;
            setKeyParams(markForDeletionCommand, obj, entity);
            q.addCommand(markForDeletionCommand);
            q.execute();
        }

        public function remove(obj:Object, responder:IResponder):void
        {
            var q:BlockingExecutor = new BlockingExecutor();
            q.setResponder(responder);

            // if not already part of a programmer-defined transaction, then
            // start one to group all cascade 'delete' operations
            if (!inTransaction)
            {
                q.addCommand(new BeginCommand(sqlConnection));
                removeObj(obj, q);
                q.addCommand(new CommitCommand(sqlConnection));
            }
            else
            {
                removeObj(obj, q);
            }
            q.execute();
        }

        public function removeItem(c:Class, id:int, responder:IResponder):void
        {
            load(c, id, new Responder(
                function(event:EntityEvent):void
                {
                    remove(event.data, responder);
                },
                function(error:EntityError):void
                {
                    trace(error);
                    responder.fault(error);
                }
            ));
        }

        private function removeObj(obj:Object, q:BlockingExecutor):void
        {
            var c:Class = getClass(obj);
            var cn:String = getClassName(c);
            var entity:Entity = map[cn];
            if (entity == null || !entity.initialisationComplete)
            {
                entity = introspector.loadMetadata(c, null, q);
            }
            removeOneToManyAssociations(obj, entity, q.branchNonBlocking());

            // Doesn't make sense to support cascade delete on many-to-many associations

            var deleteCommand:DeleteCommand = entity.deleteCommand;
            setKeyParams(deleteCommand, obj, entity);
            q.addCommand(deleteCommand);
            if (!entity.hasCompositeKey())
            {
                var id:int = obj[entity.pk.property];
                removeSuperEntity(id, entity.superEntity, q);
            }
            removeManyToOneAssociations(obj, entity, q.branchNonBlocking());
        }

        // TODO I had changed this for performance, but I should revert back
        // to iterating through and removeObj to remove the object graph to
        // effect any cascade delete on associations of the removed object.
        private function removeOneToManyAssociations(obj:Object, entity:Entity, executor:NonBlockingExecutor):void
        {
            for each(var a:OneToManyAssociation in entity.oneToManyAssociations)
            {
                if (isCascadeDelete(a))
                {
                    var deleteCommand:DeleteCommand = a.deleteCommand;
                    setKeyParams(deleteCommand, obj, entity);
                    executor.addCommand(deleteCommand);
                }
                // TODO else set the FK to 0 ?
            }
        }

        private function removeSuperEntity(id:int, superEntity:Entity, q:BlockingExecutor):void
        {
            if (superEntity == null)
                return;

            var deleteCommand:DeleteCommand = superEntity.deleteCommand;
            deleteCommand.setParam(superEntity.pk.property, id);
            q.addCommand(deleteCommand);
        }

        private function removeManyToOneAssociations(obj:Object, entity:Entity, executor:NonBlockingExecutor):void
        {
            for each(var a:Association in entity.manyToOneAssociations)
            {
                var value:Object = obj[a.property];
                if (value && isCascadeDelete(a))
                {
                    removeObj(value, executor.branchBlocking());
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
                setSuperProperties(instance, id, entity.superEntity, q);
            }

            var executor:NonBlockingExecutor = q.branchNonBlocking();
            for each(var mto:Association in entity.manyToOneAssociations)
            {
                setManyToOneAssociation(instance, row, mto, executor.branchBlocking());
            }

            var otm:OneToManyAssociation;
            var mtm:ManyToManyAssociation;

            // must be after primary key on instance has been set
            // or composite keys have been loaded
            if (entity.hasCompositeKey())
            {
                q.addFunction(function(data:Object):void
                {
                    setCachedValue(instance, entity);

                    var exec:NonBlockingExecutor = q.branchNonBlocking();
                    for each(otm in entity.oneToManyAssociations)
                    {
                        setOneToManyAssociation(instance, row, otm, entity, exec.branchBlocking());
                    }
                    for each(mtm in entity.manyToManyAssociations)
                    {
                        setManyToManyAssociation(instance, row, mtm, entity, exec.branchBlocking());
                    }
                }, "set cached value and load list associations");
            }
            else
            {
                setCachedValue(instance, entity);

                for each(otm in entity.oneToManyAssociations)
                {
                    setOneToManyAssociation(instance, row, otm, entity, executor.branchBlocking());
                }
                for each(mtm in entity.manyToManyAssociations)
                {
                    setManyToManyAssociation(instance, row, mtm, entity, executor.branchBlocking());
                }
            }

            return instance;
        }

        private function setSuperProperties(
            instance:Object,
            id:int,
            superEntity:Entity,
            q:BlockingExecutor):void
        {
            if (superEntity == null)
                return;

            var selectCommand:SelectCommand = superEntity.selectCommand;
            selectCommand.setParam(superEntity.pk.property, id);
            q.addCommand(selectCommand);
            q.addFunction(function(data:Object):void
            {
                var superInstance:Object = typeObject(data[0], superEntity, q);
                for each(var f:Field in superEntity.fields)
                {
                    instance[f.property] = superInstance[f.property];
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
            });
        }

        private function setManyToOneAssociation(
            instance:Object,
            row:Object,
            a:Association,
            q:BlockingExecutor):void
        {
            var value:Object = getCachedValue(a.associatedEntity, getFkMap(row, a.associatedEntity));
            if (value)
            {
                instance[a.property] = value;
            }
            else
            {
                var keyMap:Object = getKeyMap(row, a.associatedEntity);
                if (keyMap)
                {
                    var selectCommand:SelectCommand = a.associatedEntity.selectCommand;
                    setKeyMapParams(selectCommand, keyMap);
                    q.addCommand(selectCommand, "select " + a.associatedEntity.name);
                    q.addFunction(function(data:Object):void
                    {
                        if (data)
                        {
                            instance[a.property] = typeObject(data[0], a.associatedEntity, q);
                        }
                    }, "set instance");
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
            // Lazy Loading not supported using the Asynchronous API
//			if (a.lazy)
//			{
//				instance[a.property] = new LazyList(this, a, id);
//			}
//			else
//			{
                var selectCommand:SelectCommand = a.selectCommand;
                for each(var key:Key in entity.keys)
                {
                    selectCommand.setParam(key.fkProperty, row[key.column]);
                }
                q.addCommand(selectCommand);
                q.addFunction(function(data:Object):void
                {
                    instance[a.property] = typeArray(data as Array, a.associatedEntity, q);
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
            // Lazy Loading not supported using the Asynchronous API
//			if (a.lazy)
//			{
//				instance[a.property] = new LazyList(this, a, id);
//			}
//			else
//			{
                var selectCommand:SelectManyToManyCommand = a.selectCommand;
                for each(var key:Key in entity.keys)
                {
                    selectCommand.setParam(key.fkProperty, row[key.column]);
                }
                q.addCommand(selectCommand);
                q.addFunction(function(data:Object):void
                {
                    instance[a.property] = typeArray(data as Array, a.associatedEntity, q);
                });
//			}
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