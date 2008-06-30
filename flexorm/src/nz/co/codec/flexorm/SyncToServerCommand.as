package nz.co.codec.flexorm
{
    import flash.data.SQLConnection;
    import flash.data.SQLStatement;
    import flash.utils.Dictionary;

    import mx.rpc.IResponder;

    import nz.co.codec.flexorm.command.SelectIdMapCommand;
    import nz.co.codec.flexorm.command.SelectMarkedForDeletionCommand;
    import nz.co.codec.flexorm.command.SelectUnsynchronisedCommand;
    import nz.co.codec.flexorm.metamodel.Association;
    import nz.co.codec.flexorm.metamodel.Entity;
    import nz.co.codec.flexorm.metamodel.Field;
    import nz.co.codec.flexorm.metamodel.Key;
    import nz.co.codec.flexorm.metamodel.PrimaryIdentity;
    import nz.co.codec.flexorm.util.HTTPMethod;
    import nz.co.codec.flexorm.util.Inflector;
    import nz.co.codec.flexorm.util.ServiceCommand;
    import nz.co.codec.flexorm.util.StringUtils;

    public class SyncToServerCommand extends SynchronisationCommandBase implements IResponder
    {
        private var _em:EntityManager;

        private var _debugLevel:int;

        private var lastSyncDate:Date;

        private var count:int;

        public function SyncToServerCommand(
            entity:Entity,
            syncMap:Object,
            url:String,
            sqlConnection:SQLConnection,
            credentials:Object,
            em:EntityManager,
            debugLevel:int)
        {
            super(entity, syncMap, url, sqlConnection, credentials);
            _em = em;
            _debugLevel = debugLevel;
        }

        override public function execute():void
        {
            var executor:NonBlockingExecutor = new NonBlockingExecutor();
            executor.setResponder(this);
            var cn:String = _entity.className;
            lastSyncDate = getLastSyncDate(cn);
            var unsynchronised:Array = getUnsynchronised(_entity, lastSyncDate);
            var markedForDeletion:Array = getMarkedForDeletion(_entity.table);
            count = unsynchronised? unsynchronised.length : 0;
            count += markedForDeletion? markedForDeletion.length : 0;
            var pkMap:Dictionary = getPKMap(_entity);
            _syncMap[cn] = pkMap;
            for each(var row:Object in unsynchronised)
            {
                if (_entity.hasCompositeKey())
                {
                    // TODO
                }
                else
                {
                    var serverId:int = row.server_id;
                    if (serverId > 0)
                    {
                        // Update Server (PUT)
                        executor.addCommand(new ServiceCommand(
                            getBaseUrl(_url) + Inflector.pluralize(StringUtils.underscore(cn)) + "/" + serverId + ".xml",
                            HTTPMethod.PUT, toUpdateObject(row, _entity), null, _credentials
                        ));
                    }
                    else // Insert to Server (POST)
                    {
                        // !important that next statement is 'pass by value' thanks
                        // to primitive assignment since 'item' is reassigned in
                        // the containing for loop before the closure below can
                        // execute
                        var localId:int = row[_entity.pk.column];
                        insertToServer(getBaseUrl(_url) + Inflector.pluralize(StringUtils.underscore(cn)) + ".xml",
                            localId, row, _entity, executor);
                    }
                }
            }
            for each(var marked:Object in markedForDeletion)
            {
                if (_entity.hasCompositeKey())
                {
                    // TODO
                }
                else
                {
                    var id:int = marked[_entity.pk.column];
                    deleteItem(getBaseUrl(_url) + Inflector.pluralize(StringUtils.underscore(cn)) + "/" + marked.server_id + ".xml",
                        id, marked, _entity, executor);
                }
            }
            executor.execute();
        }

        public function result(data:Object):void
        {
            updateAppData(lastSyncDate, _entity.className);
            _responder.result(new EntityEvent(count));
        }

        public function fault(info:Object):void
        {
            trace(info);
            _responder.fault(new EntityError(info.toString()));
        }

        /**
         * A Map of the local PK value as the key to server_id
         */
        private function getPKMap(entity:Entity):Dictionary
        {
            if (entity.hasCompositeKey())
            {
                return null;
            }
            var selectCommand:SelectIdMapCommand = entity.selectIdMapCommand;
            selectCommand.execute();
            var idMap:Dictionary = new Dictionary();
            for each(var row:Object in selectCommand.result)
            {
                idMap[entity.pk.column] = row[row.server_id];
            }
            return idMap;
        }

        private function getUnsynchronised(entity:Entity, lastSyncDate:Date):Array
        {
            var selectCommand:SelectUnsynchronisedCommand = _entity.selectUnsynchronisedCommand;
            selectCommand.setParam("lastSyncDate", lastSyncDate);
            selectCommand.execute();
            return selectCommand.result;
        }

        private function getMarkedForDeletion(table:String):Array
        {
            var selectCommand:SelectMarkedForDeletionCommand = new SelectMarkedForDeletionCommand(table, _sqlConnection, _debugLevel);
            selectCommand.execute();
            return selectCommand.result;
        }

        private function insertToServer(url:String, id:int, item:Object, entity:Entity, executor:IExecutor):void
        {
            executor.addCommand(new ServiceCommand(url, HTTPMethod.POST, toUpdateObject(item, entity),
                function(data:Object):void
                {
                    var pk:PrimaryIdentity = entity.pk;
                    var updateStatement:SQLStatement = new SQLStatement();
                    updateStatement.sqlConnection = _sqlConnection;
                    updateStatement.text = "update main." + entity.table +
                        " set server_id=:serverId where " + pk.column + "=:id";
                    updateStatement.parameters[":id"] = id;
                    updateStatement.parameters[":serverId"] = int(data.result[pk.column]);
                    updateStatement.execute();
                }
                , _credentials
            ));
        }

        private function deleteItem(url:String, id:int, row:Object, entity:Entity, executor:IExecutor):void
        {
            executor.addCommand(new ServiceCommand(url, HTTPMethod.PUT, toUpdateObject(row, entity, true),
                function(data:Object):void
                {
                    _em.removeItem(entity.cls, id);
                }
                , _credentials
            ));
        }

        private function toUpdateObject(row:Object, entity:Entity, markedForDeletion:Boolean=false):Object
        {
            var table:String = entity.tableSingular;
            function getField(column:String):String
            {
                return table + "[" + column + "]";
            }

            var obj:Object = new Object;

            // Let Rails set timestamp fields automatically

            obj[getField("marked_for_deletion")] = markedForDeletion.toString();
            for each(var f:Field in entity.fields)
            {
                if (entity.hasCompositeKey() || (f.property != entity.pk.property))
                {
                    if (f.type == SQLType.BOOLEAN)
                    {
                        obj[getField(f.column)] = row[f.column].toString();
                    }
                    else
                    {
                        obj[getField(f.column)] = row[f.column];
                    }
                }
            }
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
                    obj[getField(key.fkColumn)] = idMap[row[key.fkColumn]];
                }
            }
            return obj;
        }

    }
}