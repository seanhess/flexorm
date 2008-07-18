package nz.co.codec.flexorm
{
    import flash.data.SQLConnection;
    import flash.utils.Dictionary;
    import flash.utils.getDefinitionByName;
    import flash.utils.getQualifiedClassName;

    import nz.co.codec.flexorm.command.InsertCommand;
    import nz.co.codec.flexorm.command.SQLParameterisedCommand;
    import nz.co.codec.flexorm.command.UpdateCommand;
    import nz.co.codec.flexorm.metamodel.Association;
    import nz.co.codec.flexorm.metamodel.Entity;
    import nz.co.codec.flexorm.metamodel.Field;
    import nz.co.codec.flexorm.metamodel.Key;
    import nz.co.codec.flexorm.util.Mixin;
    import nz.co.codec.flexorm.util.PersistentEntity;

    public class EntityManagerBase
    {
        // a hash of entity metadata using the entity class name as key
        protected var map:Object = new Object();

        protected var _sqlConnection:SQLConnection;

        private var _introspector:EntityIntrospector;

        private var _debugLevel:int = 0;

        // identity map
        private var cacheMap:Object = new Object();

        private var _legacySupport:Boolean = false;

        private var _syncSupport:Boolean = false;

        public function EntityManagerBase() { }

        /**
         * To support databases created by FlexORM before I changed the
         * column naming convention to use underscores instead of camelCase.
         */
        public function set legacySupport(value:Boolean):void
        {
            _legacySupport = value;
        }

        public function set syncSupport(value:Boolean):void
        {
            _syncSupport = value;
        }

        public function get syncSupport():Boolean
        {
            return _syncSupport;
        }

        public function set introspector(value:EntityIntrospector):void
        {
            _introspector = value;
        }

        public function get introspector():EntityIntrospector
        {
            if (_introspector == null)
            {
                _introspector = new EntityIntrospector(map, _sqlConnection,
                    (_legacySupport)?
                        NamingStrategy.CAMEL_CASE_NAMES :
                        NamingStrategy.UNDERSCORE_NAMES,
                    _syncSupport);
                _introspector.debugLevel = _debugLevel;
            }
            return _introspector;
        }

        public function get metadata():Object
        {
            return map;
        }

        public function set sqlConnection(value:SQLConnection):void
        {
            _sqlConnection = value;
        }

        public function get sqlConnection():SQLConnection
        {
            return _sqlConnection;
        }

        public function makePersistent(cls:Class):void
        {
            Mixin.extendClass(cls, PersistentEntity);
            cls.myClass = cls;
        }

        public function set debugLevel(value:int):void
        {
            _debugLevel = value;
            _introspector = null;
        }

        public function get debugLevel():int
        {
            return _debugLevel;
        }

        protected function getClass(obj:Object):Class
        {
            return (obj is PersistentEntity)?
                obj.myClass :
                Class(getDefinitionByName(getQualifiedClassName(obj)));
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
                    setFkParams(command, value, associatedEntity);
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

        protected function isDynamicObject(obj:Object):Boolean
        {
            return (getClassName(getClass(obj)) == "Object");
        }

        protected function setKeyMapParams(command:SQLParameterisedCommand, keyMap:Object):void
        {
            for (var key:String in keyMap)
            {
                command.setParam(key, keyMap[key]);
            }
        }

        protected function setKeyParams(command:SQLParameterisedCommand, obj:Object, entity:Entity):void
        {
            for each(var key:Key in entity.keys)
            {
                command.setParam(key.property, key.getIdValue(obj));
            }
        }

        protected function setFkParams(command:SQLParameterisedCommand, obj:Object, entity:Entity):void
        {
            for each(var key:Key in entity.keys)
            {
                command.setParam(key.fkProperty, key.getIdValue(obj));
            }
        }

        protected function setForeignKeyParams(command:SQLParameterisedCommand, foreignKeys:Array):void
        {
            for each(var fk:Object in foreignKeys)
            {
                command.setParam(fk.property, fk.id);
            }
        }

        protected function getForeignKeys(obj:Object, entity:Entity):Array
        {
            var foreignKeys:Array = [];
            for each(var key:Key in entity.keys)
            {
                foreignKeys.push({
                    property: key.fkProperty,
                    id: key.getIdValue(obj)
                });
            }
            return foreignKeys;
        }

        protected function getKeyMap(row:Object, entity:Entity):Object
        {
            var keyMap:Object = new Object();
            for each(var key:Key in entity.keys)
            {
                var id:int = row[key.fkColumn];
                if (id == 0)
                    return null;

                keyMap[key.property] = id;
            }
            return keyMap;
        }

        protected function getFkMap(row:Object, entity:Entity):Object
        {
            var fkMap:Object = new Object();
            for each(var key:Key in entity.keys)
            {
                var id:int = row[key.fkColumn];
                if (id == 0)
                    return null;

                fkMap[key.fkProperty] = id;
            }
            return fkMap;
        }

        protected function getClassName(c:Class):String
        {
            var qname:String = getQualifiedClassName(c);
            return qname.substring(qname.lastIndexOf(":") + 1);
        }

        protected function setCachedValue(obj:Object, entity:Entity):void
        {
            getCache(entity.name)[getCacheKey(obj, map[entity.name])] = obj;
        }

        private function getCacheKey(obj:Object, entity:Entity):Object
        {
            var cacheKey:Object = new Object();
            for each(var key:Key in entity.keys)
            {
                cacheKey[key.fkProperty] = key.getIdValue(obj);
            }
            return cacheKey;
        }

        protected function getCachedAssociationValue(a:Association, row:Object):Object
        {
            var associatedEntity:Entity = a.associatedEntity;
            if (associatedEntity.hasCompositeKey())
            {
                return getCachedValue(associatedEntity, getFkMap(row, associatedEntity));
            }
            else
            {
                var cacheKey:Object = new Object();
                cacheKey[associatedEntity.fkProperty] = row[a.fkColumn];
                return getCachedValue(associatedEntity, cacheKey);
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

    }
}