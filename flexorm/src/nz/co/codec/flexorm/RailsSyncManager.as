package nz.co.codec.flexorm
{
    import flash.data.SQLConnection;
    import flash.utils.getQualifiedClassName;

    import mx.rpc.IResponder;

    import nz.co.codec.flexorm.metamodel.Association;
    import nz.co.codec.flexorm.metamodel.Entity;
    import nz.co.codec.flexorm.metamodel.Key;

    public class RailsSyncManager
    {
        private var _em:EntityManager;

        private var _introspector:EntityIntrospector;

        private var _map:Object;

        private var _sqlConnection:SQLConnection;

        private var _debugLevel:int;

        private var _credentials:Object;

        private var syncFromServerMap:Object;

        private var syncToServerMap:Object;

        public function RailsSyncManager(em:EntityManager, credentials:Object=null)
        {
            _em = em;
            _introspector = em.introspector;
            _map = em.metadata;
            _sqlConnection = em.sqlConnection;
            _debugLevel = em.debugLevel;
            _credentials = credentials;
            syncFromServerMap = new Object();
            syncToServerMap = new Object();
        }

        public function syncFromServer(c:Class, url:String, responder:IResponder):void
        {
            var q:BlockingExecutor = new BlockingExecutor();
            q.setResponder(responder);
            var entity:Entity = getEntity(c);

            // Sync FK dependent entities -------------------------

            var key:Key;
            var keyEntity:Entity;
            var branch:NonBlockingExecutor = q.branchNonBlocking();

            if (entity.hasCompositeKey())
            {
                for each(key in entity.keys)
                {
                    keyEntity = key.getRootEntity();
                    branch.addCommand(new SyncFromServerCommand(keyEntity, syncFromServerMap, url, _sqlConnection, _credentials));
                }
            }
            for each(var a:Association in entity.manyToOneAssociations)
            {
                if (a.associatedEntity.hasCompositeKey())
                {
                    for each(key in a.associatedEntity.keys)
                    {
                        keyEntity = key.getRootEntity();
                        if (!syncFromServerMap.hasOwnProperty(keyEntity.className))
                        {
                            branch.addCommand(new SyncFromServerCommand(keyEntity, syncFromServerMap, url, _sqlConnection, _credentials));
                        }
                    }
                }
                else
                {
                    if (!syncFromServerMap.hasOwnProperty(a.associatedEntity.className))
                    {
                        branch.addCommand(new SyncFromServerCommand(a.associatedEntity, syncFromServerMap, url, _sqlConnection, _credentials));
                    }
                }
            }

            q.addCommand(new SyncFromServerCommand(entity, syncFromServerMap, url, _sqlConnection, _credentials));
            q.execute();
        }

        public function syncToServer(c:Class, url:String, responder:IResponder):void
        {
            var q:BlockingExecutor = new BlockingExecutor();
            q.setResponder(responder);
            var entity:Entity = getEntity(c);

            // Sync FK dependent entities -------------------------

            var key:Key;
            var keyEntity:Entity;
            var branch:NonBlockingExecutor = q.branchNonBlocking();

            if (entity.hasCompositeKey())
            {
                for each(key in entity.keys)
                {
                    keyEntity = key.getRootEntity();
                    branch.addCommand(new SyncToServerCommand(keyEntity, syncToServerMap, url, _sqlConnection, _credentials, _em, _debugLevel));
                }
            }
            for each(var a:Association in entity.manyToOneAssociations)
            {
                if (a.associatedEntity.hasCompositeKey())
                {
                    for each(key in a.associatedEntity.keys)
                    {
                        keyEntity = key.getRootEntity();
                        if (!syncFromServerMap.hasOwnProperty(keyEntity.className))
                        {
                            branch.addCommand(new SyncToServerCommand(keyEntity, syncToServerMap, url, _sqlConnection, _credentials, _em, _debugLevel));
                        }
                    }
                }
                else
                {
                    if (!syncFromServerMap.hasOwnProperty(a.associatedEntity.className))
                    {
                        branch.addCommand(new SyncToServerCommand(a.associatedEntity, syncToServerMap, url, _sqlConnection, _credentials, _em, _debugLevel));
                    }
                }
            }

            q.addCommand(new SyncToServerCommand(entity, syncToServerMap, url, _sqlConnection, _credentials, _em, _debugLevel));
            q.execute();
        }

        private function getEntity(c:Class):Entity
        {
            var cn:String = getClassName(c);
            var entity:Entity = _map[cn];
            if (entity == null || !entity.initialisationComplete)
            {
                entity = _introspector.loadMetadata(c);
            }
            return entity;
        }

        private function getClassName(c:Class):String
        {
            var qname:String = getQualifiedClassName(c);
            return qname.substring(qname.lastIndexOf(".") + 1);
        }

    }
}