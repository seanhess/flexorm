package nz.co.codec.flexorm
{
    import com.adobe.utils.DateUtil;

    import flash.data.SQLConnection;
    import flash.utils.Dictionary;

    import mx.rpc.Responder;

    import nz.co.codec.flexorm.command.DeleteCommand;
    import nz.co.codec.flexorm.command.InsertCommand;
    import nz.co.codec.flexorm.command.SQLParameterisedCommand;
    import nz.co.codec.flexorm.command.SelectFkMapCommand;
    import nz.co.codec.flexorm.command.SelectIdMapCommand;
    import nz.co.codec.flexorm.command.UpdateCommand;
    import nz.co.codec.flexorm.metamodel.Association;
    import nz.co.codec.flexorm.metamodel.Entity;
    import nz.co.codec.flexorm.metamodel.Field;
    import nz.co.codec.flexorm.metamodel.Key;
    import nz.co.codec.flexorm.util.HTTPMethod;
    import nz.co.codec.flexorm.util.Inflector;
    import nz.co.codec.flexorm.util.ServiceUtil;
    import nz.co.codec.flexorm.util.StringUtils;

    public class SyncFromServerCommand extends SynchronisationCommandBase
    {
        public function SyncFromServerCommand(
            entity:Entity,
            syncMap:Object,
            url:String,
            sqlConnection:SQLConnection,
            credentials:Object)
        {
            super(entity, syncMap, url, sqlConnection, credentials);
        }

        override public function execute():void
        {
            ServiceUtil.send(getBaseUrl(_url) +
                Inflector.pluralize(StringUtils.underscore(_entity.className)) +
                ".xml", new Responder(
                function(data:Object):void
                {
                    var cn:String = _entity.className;
                    var c_n:String = StringUtils.underscore(cn);
                    var lastSyncDate:Date = getLastSyncDate(cn);
                    var list:XMLList = data.result[c_n];
                    var fkMaps:Array = getFKMaps(_entity);
                    var pkMap:Dictionary = getPKMap(_entity);
                    _syncMap[cn] = pkMap;
                    var key:Key;

                    // sum number of records
                    var total:int = 0;
                    for each(var it:XML in list)
                    {
                        total++;
                    }
                    var count:int = 0;
                    for each(var item:XML in list)
                    {
                        // parse Rails datetime
                        var updatedAt:Date = DateUtil.parseW3CDTF(item.updated_at);
                        if (updatedAt.time > lastSyncDate.time)
                        {
                            var localKeyMap:Object = getLocalKeyMap(item, _entity);

                            // check for local copy of record
                            var match:Boolean = false;
                            if (_entity.hasCompositeKey())
                            {
                                for each(var fkMap:Object in fkMaps)
                                {
                                    match = true;
                                    for each(key in _entity.keys)
                                    {
                                        if (fkMap[key.property] != localKeyMap[key.property])
                                        {
                                            match = false;
                                            break;
                                        }
                                    }
                                    if (match)
                                        break;
                                }
                            }
                            else
                            {
                                if (localKeyMap[_entity.pk.property] > 0)
                                    match = true;
                            }

                            if (match) // found local copy of record
                            {
                                if (StringUtils.parseBoolean(item.marked_for_deletion, false))
                                {
                                    var deleteCommand:DeleteCommand = _entity.deleteCommand;
                                    for each(key in _entity.keys)
                                    {
                                        deleteCommand.setParam(key.property, localKeyMap[key.property]);
                                    }
                                    deleteCommand.execute();
                                }
                                else
                                {
                                    var updateCommand:UpdateCommand = _entity.updateCommand;
                                    setFieldParams(updateCommand, _entity, item);
                                    setManyToOneAssociationParams(updateCommand, item, _entity);
                                    setUpdateTimestampParams(updateCommand);
                                    updateCommand.execute();
                                }
                            }
                            else
                            {
                                var insertCommand:InsertCommand = _entity.insertCommand;
                                if (!_entity.hasCompositeKey())
                                {
                                    insertCommand.setParam("serverId", item[_entity.pk.column]);
                                }
                                insertCommand.setParam("markedForDeletion", false);
                                setFieldParams(insertCommand, _entity, item);
                                setManyToOneAssociationParams(insertCommand, item, _entity);
                                setInsertTimestampParams(insertCommand);
                                insertCommand.execute();
                            }
                            count++;
                        }
                    }
                    updateAppData(lastSyncDate, cn);

                    _responder.result(new EntityEvent(count));

                },
                function(info:Object):void
                {
                    trace(info);
                    _responder.fault(new EntityError(info.toString()));
                }
            ), HTTPMethod.GET, null, _credentials);
        }

        /**
         * A Map of server_id as the key to the local PK value
         */
        private function getPKMap(entity:Entity):Dictionary
        {
            if (entity.hasCompositeKey())
            {
                return null;
//                throw new Error("getPKMap called with '" + entity.className +
//                    "', which has composite keys.");
            }
            var selectCommand:SelectIdMapCommand = entity.selectIdMapCommand;
            selectCommand.execute();
            var idMap:Dictionary = new Dictionary();
            for each(var row:Object in selectCommand.result)
            {
                idMap[row.server_id] = row[entity.pk.column];
            }
            return idMap;
        }

        private function getFKMaps(entity:Entity):Array
        {
            if (!entity.hasCompositeKey())
            {
                return null;
//                throw new Error("getFKMaps called with '" + entity.className +
//                    "', which has a primary key.");
            }
            var selectCommand:SelectFkMapCommand = entity.selectFkMapCommand;
            selectCommand.execute();
            var maps:Array = [];
            for each(var row:Object in selectCommand.result)
            {
                var idMap:Object = new Object();
                for each(var key:Key in entity.keys)
                {
                    idMap[key.property] = row[key.column];
                }
                maps.push(idMap);
            }
            return maps;
        }

        private function getLocalKeyMap(item:XML, entity:Entity):Object
        {
            var keyMap:Object = new Object();
            var cn:String = entity.className;
            for each(var key:Key in entity.keys)
            {
                if (entity.hasCompositeKey())
                {
                    cn = key.getRootEntity().className;
                }
                var idMap:Dictionary = _syncMap[cn];
                if (idMap == null)
                {
                    throw new Error("Dependency on synchronisation of '" + cn + "'");
                }
                keyMap[key.property] = idMap[item[key.column]];
            }
            return keyMap;
        }
/*
        private function getServerIdMap(localIdMap:Object, entity:Entity):Object
        {
            if (!entity.hasCompositeKey())
            {
                throw new Error("getServerIdMap called with '" +
                    entity.className + "', which has a primary key.");
            }
            var serverIdMap:Object = new Object();
            for each(var key:Key in entity.keys)
            {
//                serverIdMap[key.property] = getServerId(localIdMap[key.property], key.getRootEntity());
            }
            return serverIdMap;
        }

        // Too inefficient loading the server_id from the local database
        // for every record
        private function getServerId(localId:int, entity:Entity):int
        {
            if (entity.hasCompositeKey())
            {
                throw new Error("getServerId called with '" + entity.className +
                    "', which has composite keys.");
            }
            var pk:PrimaryIdentity = entity.pk;
            var statement:SQLStatement = new SQLStatement();
            statement.sqlConnection = _sqlConnection;
            statement.text = "select t.server_id from " + entity.table +
                " t where " + pk.column + "=:" + pk.property;
            statement.parameters[":" + pk.property] = localId;
            statement.execute();
            var data:Array = statement.getResult().data;
            if (data == null || data.length == 0)
            {
                throw new Error("Dependency on synchronisation of '" +
                    entity.className + "'");
            }
            return int(data[0].server_id);
        }
*/
        private function setFieldParams(command:SQLParameterisedCommand, entity:Entity, item:XML):void
        {
            for each(var f:Field in entity.fields)
            {
                if (entity.hasCompositeKey() || (f.property != entity.pk.property))
                {
                    if (f.type == SQLType.INTEGER)
                    {
                        var value:String = item[f.column].toString();
                        command.setParam(f.property, (value == "")? null : int(value));
                    }
                    else if (f.type == SQLType.BOOLEAN)
                    {
                        var bool:Boolean = StringUtils.parseBoolean(item[f.column].toString(), false);
                        command.setParam(f.property, bool);
                    }
                    else
                    {
                        command.setParam(f.property, item[f.column].toString());
                    }
                }
            }
        }

        private function setManyToOneAssociationParams(command:SQLParameterisedCommand, item:XML, entity:Entity):void
        {
            for each(var a:Association in entity.manyToOneAssociations)
            {
                for each(var key:Key in a.associatedEntity.keys)
                {
                    var cn:String = a.associatedEntity.className;
                    var idMap:Dictionary = _syncMap[cn];
                    if (idMap == null)
                    {
                        throw new Error("Dependency on synchronisation of '" + cn + "'");
                    }
                    command.setParam(key.fkProperty, idMap[item[key.fkColumn]]);
                }
            }
        }

        private function setUpdateTimestampParams(updateCommand:UpdateCommand):void
        {
            updateCommand.setParam("updatedAt", new Date());
        }

        private function setInsertTimestampParams(insertCommand:InsertCommand):void
        {
            insertCommand.setParam("createdAt", new Date());
            insertCommand.setParam("updatedAt", new Date());
        }

    }
}