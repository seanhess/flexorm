package nz.co.codec.flexorm
{
    import flash.data.SQLConnection;
    import flash.utils.Dictionary;
    import flash.utils.getDefinitionByName;
    import flash.utils.getQualifiedClassName;

    import mx.collections.ArrayCollection;

    import nz.co.codec.flexorm.command.InsertCommand;
    import nz.co.codec.flexorm.command.SQLParameterisedCommand;
    import nz.co.codec.flexorm.command.UpdateCommand;
    import nz.co.codec.flexorm.metamodel.Association;
    import nz.co.codec.flexorm.metamodel.Entity;
    import nz.co.codec.flexorm.metamodel.Field;
    import nz.co.codec.flexorm.metamodel.Identity;
    import nz.co.codec.flexorm.metamodel.PersistentEntity;
    import nz.co.codec.flexorm.util.Mixin;

    public class EntityManagerBase
    {
        internal static const OBJECT_TYPE:String = "Object";

        internal static const DEFAULT_SCHEMA:String = "main";

        private var _schema:String;

        private var _sqlConnection:SQLConnection;

        private var _introspector:EntityIntrospector;

        private var _debugLevel:int;

        private var _options:Object;

        // A map of Entities using the Entity name as key
        private var _entityMap:Object;

        // Identity Map
        private var cacheMap:Object;

        private var cachedChildrenMap:Object;

        public function EntityManagerBase()
        {
            _schema = DEFAULT_SCHEMA;
            _options = {};
            _options.namingStrategy = NamingStrategy.UNDERSCORE_NAMES;
            _options.syncSupport = false;
            _debugLevel = 0;
            _entityMap = {};
            clearCache();
        }

        public function get schema():String
        {
            return _schema;
        }

        public function set sqlConnection(value:SQLConnection):void
        {
            _sqlConnection = value;
            _introspector = new EntityIntrospector(_schema, value, _entityMap, _debugLevel, _options);
        }

        public function get sqlConnection():SQLConnection
        {
            return _sqlConnection;
        }

        public function set introspector(value:EntityIntrospector):void
        {
            _introspector = value;
        }

        public function get introspector():EntityIntrospector
        {
            return _introspector;
        }

        public function set debugLevel(value:int):void
        {
            _debugLevel = value;
            if (_introspector)
                _introspector.debugLevel = value;
        }

        public function get debugLevel():int
        {
            return _debugLevel;
        }

        /**
         * Valid options include:
         *
         * - namingStrategy:String
         *     Valid values:
         *       NamingStrategy.UNDERSCORE
         *       NamingStrategy.CAMEL_CASE
         *         FlexORM versions prior to 0.8 used camelCase.
         *
         * - syncSupport:Boolean
         *
         */
        public function set options(value:Object):void
        {
            if (value)
            {
                _options = value;
                if (value.hasOwnProperty("schema"))
                    _schema = value.schema;
            }
        }

        public function get options():Object
        {
            return _options;
        }

        public function get entityMap():Object
        {
            return _entityMap;
        }

        public function makePersistent(cls:Class):void
        {
            Mixin.extendClass(cls, PersistentEntity);

            // A reference to the original class type since a side effect of
            // Mixin is to change cls type to PersistentEntity
            cls.__class = cls;
        }

        protected function getClass(obj:Object):Class
        {
            return (obj is PersistentEntity) ?
                obj.__class :
                Class(getDefinitionByName(getQualifiedClassName(obj)));
        }

        protected function getIdentityMap(key:String, id:int):Object
        {
            var map:Object = {};
            map[key] = id;
            return map;
        }

        protected function getIdentityMapFromInstance(obj:Object, entity:Entity):Object
        {
            var map:Object = {};
            for each(var identity:Identity in entity.identities)
            {
                map[identity.fkProperty] = identity.getValue(obj);
            }
            return map;
        }

        protected function getIdentityMapFromRow(row:Object, entity:Entity):Object
        {
            var map:Object = {};
            for each(var identity:Identity in entity.identities)
            {
                var id:* = row[identity.column];
                if (id == 0 || id == null)
                    return null;
                map[identity.fkProperty] = id;
            }
            return map;
        }

        protected function getIdentityMapFromAssociation(row:Object, entity:Entity):Object
        {
            var map:Object = {};
            for each(var identity:Identity in entity.identities)
            {
                var id:* = row[identity.fkColumn];
                if (id == 0 || id == null)
                    return null;
                map[identity.fkProperty] = id;
            }
            return map;
        }

        protected function combineMaps(maps:Array):Object
        {
            var result:Object = {};
            for each(var map:Object in maps)
            {
                for (var key:String in map)
                {
                    result[key] = map[key];
                }
            }
            return result;
        }

        protected function setIdentMapParams(command:SQLParameterisedCommand, idMap:Object):void
        {
            for (var key:String in idMap)
            {
                command.setParam(key, idMap[key]);
            }
        }

        protected function setIdentityParams(command:SQLParameterisedCommand, obj:Object, entity:Entity):void
        {
            for each(var identity:Identity in entity.identities)
            {
                command.setParam(identity.fkProperty, identity.getValue(obj));
            }
        }

        protected function setFieldParams(command:SQLParameterisedCommand, obj:Object, entity:Entity):void
        {
            for each(var f:Field in entity.fields)
            {
                if (entity.hasCompositeKey() || (f.property != entity.pk.property))
                {
                    command.setParam(f.property, obj[f.property]);
                }
            }
        }

        protected function setManyToOneAssociationParams(command:SQLParameterisedCommand, obj:Object, entity:Entity):void
        {
            for each(var a:Association in entity.manyToOneAssociations)
            {
                var associatedEntity:Entity = a.associatedEntity;
                var value:Object = obj[a.property];
                if (associatedEntity.hasCompositeKey())
                {
                    setIdentityParams(command, value, associatedEntity);
                }
                else
                {
                    if (value == null)
                    {
                        command.setParam(a.fkProperty, 0);
                    }
                    else
                    {
                        command.setParam(a.fkProperty, value[associatedEntity.pk.property]);
                    }
                }
            }
        }

        protected function setInsertTimestampParams(insertCommand:InsertCommand):void
        {
            insertCommand.setParam("createdAt", new Date());
            insertCommand.setParam("updatedAt", new Date());
        }

        protected function setUpdateTimestampParams(updateCommand:UpdateCommand):void
        {
            updateCommand.setParam("updatedAt", new Date());
        }

        protected function isCascadeSave(a:Association):Boolean
        {
            return (a.cascadeType == CascadeType.SAVE_UPDATE || a.cascadeType == CascadeType.ALL);
        }

        protected function isCascadeDelete(a:Association):Boolean
        {
            return (a.cascadeType == CascadeType.DELETE || a.cascadeType == CascadeType.ALL);
        }

        protected function getClassName(c:Class):String
        {
            var qname:String = getQualifiedClassName(c);
            return qname.substring(qname.lastIndexOf(":") + 1);
        }

        protected function setCachedValue(obj:Object, entity:Entity):void
        {
            getCache(entity.name)[getIdentityMapFromInstance(obj, entity)] = obj;
        }

        protected function getCachedAssociationValue(a:Association, row:Object):Object
        {
            var associatedEntity:Entity = a.associatedEntity;
            if (associatedEntity.hasCompositeKey())
            {
                return getCachedValue(associatedEntity, getIdentityMapFromAssociation(row, associatedEntity));
            }
            else
            {
                return getCachedValue(associatedEntity, getIdentityMap(associatedEntity.fkProperty, row[a.fkColumn]));
            }
        }

        protected function getCachedValue(entity:Entity, cacheKey:Object):Object
        {
            if (cacheKey == null)
                return null;

            var cache:Dictionary = getCache(entity.name);
            for (var ck:Object in cache)
            {
                var match:Boolean = true;
                for (var k:String in cacheKey)
                {
                    if (cacheKey[k] != ck[k])
                    {
                        match = false;
                        break;
                    }
                }
                if (match)
                    return cache[ck];
            }
            return null;
        }

        private function getCache(name:String):Dictionary
        {
            var cache:Dictionary = cacheMap[name];
            if (cache == null)
            {
                cache = new Dictionary();
                cacheMap[name] = cache;
            }
            return cache;
        }

        protected function clearCache():void
        {
            cacheMap = {};
            cachedChildrenMap = {};
        }

        protected function getCachedChildren(parentId:int):ArrayCollection
        {
            var coll:ArrayCollection = cachedChildrenMap[parentId];
            if (coll == null)
            {
                coll = new ArrayCollection();
                cachedChildrenMap[parentId] = coll;
            }
            return coll;
        }

        protected function isDynamicObject(obj:Object):Boolean
        {
            return (OBJECT_TYPE == getClassName(getClass(obj)));
        }

    }
}