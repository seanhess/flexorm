package nz.co.codec.flexorm
{
	import flash.data.SQLConnection;
	import flash.errors.SQLError;
	import flash.events.Event;
	import flash.filesystem.File;
	import flash.utils.getDefinitionByName;
	import flash.utils.getQualifiedClassName;
	
	import mx.collections.ArrayCollection;
	import mx.rpc.IResponder;
	
	import nz.co.codec.flexorm.command.DeleteCommand;
	import nz.co.codec.flexorm.command.FindAllCommand;
	import nz.co.codec.flexorm.command.InsertCommand;
	import nz.co.codec.flexorm.command.SelectCommand;
	import nz.co.codec.flexorm.command.SelectManyToManyCommand;
	import nz.co.codec.flexorm.command.SelectManyToManyIndicesCommand;
	import nz.co.codec.flexorm.command.UpdateCommand;
	import nz.co.codec.flexorm.metamodel.Association;
	import nz.co.codec.flexorm.metamodel.Entity;
	import nz.co.codec.flexorm.metamodel.Field;
	import nz.co.codec.flexorm.metamodel.Identity;
	import nz.co.codec.flexorm.metamodel.ManyToManyAssociation;
	import nz.co.codec.flexorm.metamodel.OneToManyAssociation;
	import nz.co.codec.flexorm.util.Mixin;
	import nz.co.codec.flexorm.util.PersistentEntity;
	
	public class EntityManager implements IEntityManager
	{
		private static var _instance:IEntityManager;
		
		private static var localInstantiation:Boolean = false;
		
		public static function get instance():IEntityManager
		{
			if (!_instance)
			{
				localInstantiation = true;
				_instance = new EntityManager();
				localInstantiation = false;
			}
			return _instance;
		}
		
		/**
		 * map is a hash of Entity definitions using the entity class as a key
		 */
		private var map:Object;
		
		/**
		 * Identity Map
		 */
		private var cache:Object;
		
		private var _sqlConnection:SQLConnection;
		
		private var _entityReflector:EntityReflector;
		
		private var _debugLevel:int = 0;
		
		private var inTransaction:Boolean = false;
		
		private var txResponder:IResponder;
		
		public function EntityManager()
		{
			if (!localInstantiation)
			{
				throw new Error("EntityManager is a singleton. Use EntityManager.instance");
			}
			map = new Object();
			cache = new Object();
		}
		
		public function set sqlConnection(value:SQLConnection):void
		{
			_sqlConnection = value;
		}
		
		public function get sqlConnection():SQLConnection
		{
			if (!_sqlConnection)
			{
				var dbFile:File = File.applicationStorageDirectory.resolvePath("default.db");
				_sqlConnection = new SQLConnection();
				_sqlConnection.open(dbFile);
				_entityReflector = null;
			}
			return _sqlConnection;
		}
		
		private function get entityReflector():EntityReflector
		{
			if (!_entityReflector)
			{
				_entityReflector = new EntityReflector(map, sqlConnection);
				_entityReflector.debugLevel = _debugLevel;
			}
			return _entityReflector;
		}
		
		public function set debugLevel(value:int):void
		{
			_debugLevel = value;
			_entityReflector = null;
		}
		
		public function get debugLevel():int
		{
			return _debugLevel;
		}
		
		public function startTransaction(responder:IResponder = null):void
		{
			txResponder = responder;
			sqlConnection.begin();
			inTransaction = true;
		}
		
		public function endTransaction():void
		{
			if (inTransaction)
			{
				try
				{
					sqlConnection.commit();
					inTransaction = false;
					txResponder.result(new Event("successful transaction"));
				}
				catch (error:SQLError)
				{
					handleSQLError(error);
				}
			}
		}
		
		public function makePersistent(c:Class):void
		{
			Mixin.extendClass(c, PersistentEntity);
			c.myClass = c;
		}
		
		public function findAll(c:Class):ArrayCollection
		{
			if (c is PersistentEntity) c = c.myClass;
			var entity:Entity = map[c];
			if (!entity || !entity.initialisationComplete)
			{
				entity = entityReflector.loadMetadata(c);
			}
			var command:FindAllCommand = entity.findAllCommand;
			command.execute();
			return typeArray(command.result, c);
		}
		
		public function loadOneToManyAssociation(a:OneToManyAssociation, id:int):ArrayCollection
		{
			var c:Class = a.associatedEntity.cls;
			var entity:Entity = map[c];
			if (!entity || !entity.initialisationComplete)
			{
				entity = entityReflector.loadMetadata(c);
			}
			return selectOneToManyAssociation(a.column, c, a.selectCommand, id);
		}
		
		public function loadManyToManyAssociation(a:ManyToManyAssociation, id:int):ArrayCollection
		{
			var c:Class = a.associatedEntity.cls;
			var entity:Entity = map[c];
			if (!entity || !entity.initialisationComplete)
			{
				entity = entityReflector.loadMetadata(c);
			}
			return selectManyToManyAssociation(a.column, c, a.selectCommand, id);
		}
		
		public function loadItem(c:Class, id:int):Object
		{
			if (c is PersistentEntity) c = c.myClass;
			var entity:Entity = map[c];
			if (!entity || !entity.initialisationComplete)
			{
				entity = entityReflector.loadMetadata(c);
			}
			var command:SelectCommand = entity.selectCommand;
			command.setParam(entity.identity.property, id);
			command.execute();
			var result:Array = command.result;
			return (result) ? typeObject(result[0], c) : null;
		}
		
		public function save(o:Object):void
		{
			// if not already part of a user-defined transaction, then
			// start one to group all cascade save-update operations
			if (!inTransaction) sqlConnection.begin();
			try {
				saveInternal(o);
				if (!inTransaction) sqlConnection.commit();
			}
			catch (error:SQLError)
			{
				handleSQLError(error);
			}
		}
		
		private function saveInternal(o:Object, join:Object = null, mtmInsertCommand:InsertCommand = null):void
		{
			if (o == null) return;
			var c:Class = null;
			if (o is PersistentEntity)
			{
				c = o.myClass;
			}
			else
			{
				c = Class(getDefinitionByName(getQualifiedClassName(o)));
			}
			var entity:Entity = map[c];
			if (!entity || !entity.initialisationComplete)
			{
				entity = entityReflector.loadMetadata(c);
			}
			var identity:Identity = entity.identity;
			var column:String = entity.fkColumn; // FK of this class c
			
			for each(var a:Association in entity.manyToOneAssociations)
			{
				if (!a.inverse &&
					(a.cascadeType == CascadeType.SAVE_UPDATE || a.cascadeType == CascadeType.ALL) &&
					o[a.property])
				{
					saveInternal(o[a.property]);
				}
			}
			
			var id:int = o[identity.property];
			if (id > 0)
			{
				updateItem(o, c, join, mtmInsertCommand);
			}
			else
			{
				createItem(o, c, join, mtmInsertCommand);
			}
			// id value of this object o
			// must place here to get updated id for created items
			id = o[identity.property];
			
			for each(var otmAssoc:OneToManyAssociation in entity.oneToManyAssociations)
			{
				if ((otmAssoc.cascadeType == CascadeType.SAVE_UPDATE || otmAssoc.cascadeType == CascadeType.ALL) &&
					(!otmAssoc.lazy ||
						(o[otmAssoc.property] &&
							(!(o[otmAssoc.property] is LazyList) ||
							(o[otmAssoc.property] is LazyList && LazyList(o[otmAssoc.property]).loaded)))))
				{
					for each(var otmItem:Object in o[otmAssoc.property])
					{
						saveInternal(otmItem, { column: column, id: id });
					}
				}
			}
			
			for each(var mtmAssoc:ManyToManyAssociation in entity.manyToManyAssociations)
			{
				if (!mtmAssoc.lazy ||
						(o[mtmAssoc.property] &&
							(!(o[mtmAssoc.property] is LazyList) ||
							(o[mtmAssoc.property] is LazyList && LazyList(o[mtmAssoc.property]).loaded))))
				{
					var selectIndicesCommand:SelectManyToManyIndicesCommand = mtmAssoc.selectIndicesCommand;
					selectIndicesCommand.setParam(column, id);
					selectIndicesCommand.execute();
					
					var preIndices:Array = [];
					
					for each(var row:Object in selectIndicesCommand.result)
					{
						preIndices.push(row[mtmAssoc.joinColumn]);
					}
					
					var idProperty:String = mtmAssoc.associatedEntity.identity.property;
					
					for each(var mtmItem:Object in o[mtmAssoc.property])
					{
						var mtmItemId:int = mtmItem[idProperty];
						var idx:int = preIndices.indexOf(mtmItemId);
						if (idx > -1)
						{
							// no need to update associationTable
							if (mtmAssoc.cascadeType == CascadeType.SAVE_UPDATE || mtmAssoc.cascadeType == CascadeType.ALL)
							{
								saveInternal(mtmItem, { column: column, id: id });
							}
							preIndices.splice(idx, 1);
						}
						else
						{
							var insertCommand:InsertCommand = mtmAssoc.insertCommand;
							
							// insert link in associationTable
							if (mtmAssoc.cascadeType == CascadeType.SAVE_UPDATE || mtmAssoc.cascadeType == CascadeType.ALL)
							{
								saveInternal(mtmItem, { column: column, id: id }, insertCommand);
							}
							else // just create the link instead
							{
								insertCommand.setParam(mtmAssoc.joinColumn, mtmItemId);
								insertCommand.setParam(column, id);
								insertCommand.execute();
							}
						}
					}
					// for each pre index left
					for each(var i:int in preIndices)
					{
						// delete link from associationTable
						var deleteCommand:DeleteCommand = mtmAssoc.deleteCommand;
						deleteCommand.setParam(column, id);
						deleteCommand.setParam(mtmAssoc.joinColumn, i);
						deleteCommand.execute();
					}
				}
			}
		}
		
		private function updateItem(o:Object, c:Class, join:Object = null, mtmInsertCommand:InsertCommand = null):void
		{
			var entity:Entity = map[c];
			
			var superEntity:Entity = entity.superEntity;
			if (superEntity)
			{
				var superUpdateCommand:UpdateCommand = superEntity.updateCommand;
				for each(var sf:Field in superEntity.fields)
				{
					superUpdateCommand.setParam(sf.property, o[sf.property]);
				}
				for each(var sa:Association in superEntity.manyToOneAssociations)
				{
					if (o[sa.property])
					{
						superUpdateCommand.setParam(sa.column, o[sa.property][sa.associatedEntity.identity.property]);
					}
					else
					{
						superUpdateCommand.setParam(sa.column, 0);
					}
				}
				superUpdateCommand.execute();
			}
			
			var command:UpdateCommand = entity.updateCommand;
			for each(var f:Field in entity.fields)
			{
				command.setParam(f.property, o[f.property]);
			}
			for each(var a:Association in entity.manyToOneAssociations)
			{
				if (o[a.property])
				{
					command.setParam(a.column, o[a.property][a.associatedEntity.identity.property]);
				}
				else
				{
					command.setParam(a.column, 0);
				}
			}
			if (join && !mtmInsertCommand) command.setParam(join.column, join.id);
			
			command.execute();
			
			if (join && mtmInsertCommand)
			{
				mtmInsertCommand.setParam(entity.fkColumn, o[entity.identity.property]);
				mtmInsertCommand.setParam(join.column, join.id);
				mtmInsertCommand.execute();
			}
		}
		
		private function createItem(o:Object, c:Class, join:Object = null, mtmInsertCommand:InsertCommand = null):void
		{
			var entity:Entity = map[c];
			var identity:Identity = entity.identity;
			var command:InsertCommand = entity.insertCommand;
			
			var superEntity:Entity = entity.superEntity;
			if (superEntity)
			{
				var superInsertCommand:InsertCommand = superEntity.insertCommand;
				for each(var sf:Field in superEntity.fields)
				{
					if (sf.property != superEntity.identity.property)
					{
						superInsertCommand.setParam(sf.property, o[sf.property]);
					}
				}
				for each(var sa:Association in superEntity.manyToOneAssociations)
				{
					if (o[sa.property])
					{
						superInsertCommand.setParam(sa.column, o[sa.property][sa.associatedEntity.identity.property]);
					}
					else
					{
						superInsertCommand.setParam(sa.column, 0);
					}
				}
				superInsertCommand.execute();
				command.setParam(identity.property, superInsertCommand.lastInsertRowID);
				o[entity.identity.property] = superInsertCommand.lastInsertRowID;
			}
			
			for each(var f:Field in entity.fields)
			{
				if (f.property != identity.property)
				{
					command.setParam(f.property, o[f.property]);
				}
			}
			for each(var a:Association in entity.manyToOneAssociations)
			{
				if (o[a.property])
				{
					command.setParam(a.column, o[a.property][a.associatedEntity.identity.property]);
				}
				else
				{
					command.setParam(a.column, 0);
				}
			}
			if (join && !mtmInsertCommand) command.setParam(join.column, join.id);
			
			command.execute();
			
			if (!entity.superEntity)
			{
				o[entity.identity.property] = command.lastInsertRowID;
			}
			
			if (join && mtmInsertCommand)
			{
				mtmInsertCommand.setParam(entity.fkColumn, command.lastInsertRowID);
				mtmInsertCommand.setParam(join.column, join.id)
				mtmInsertCommand.execute();
			}
		}
		
		public function remove(o:Object):void
		{
			var c:Class = Class(getDefinitionByName(getQualifiedClassName(o)));
			var entity:Entity = map[c];
			if (!entity || !entity.initialisationComplete)
			{
				entity = entityReflector.loadMetadata(c);
			}
			// if not already part of a user-defined transaction,
			// then start one to group all cascade delete operations
			if (!inTransaction) sqlConnection.begin();
			try {
				var a:Association = null;
				for each(a in entity.oneToManyAssociations)
				{
					if (a.cascadeType == CascadeType.DELETE || a.cascadeType == CascadeType.ALL)
					{
						for each(var item:Object in o[a.property])
						{
							remove(item);
						}
					}
				}
				
				// Doesn't make sense to support cascade delete on many-to-many associations
				
				var command:DeleteCommand = entity.deleteCommand;
				var identity:Identity = entity.identity;
				command.setParam(identity.property, o[identity.property]);
				command.execute();
				
				var superEntity:Entity = entity.superEntity;
				if (superEntity)
				{
					var superDeleteCommand:DeleteCommand = superEntity.deleteCommand;
					superDeleteCommand.setParam(superEntity.identity.property, o[identity.property]);
					superDeleteCommand.execute();
				}
				
				for each(a in entity.manyToOneAssociations)
				{
					if (o[a.property] &&
						(a.cascadeType == CascadeType.DELETE || a.cascadeType == CascadeType.ALL))
					{
						remove(o[a.property]);
					}
				}
				if (!inTransaction) sqlConnection.commit();
			}
			catch (error:SQLError)
			{
				handleSQLError(error);
			}
		}
		
		private function handleSQLError(error:SQLError):void
		{
			if (_debugLevel > 0)
			{
				trace(error);
			}
			
			// check if transaction is still open, since a foreign key
			// constraint trigger will force a rollback, which closes
			// the transaction
			if (sqlConnection.inTransaction) sqlConnection.rollback();
			inTransaction = false;
			txResponder.fault(error);
		}
		
		// TODO: consider whether to return an empty collection instead of null
		// I think I chose to return null to set empty list associations as null
		// on the owner entity
		private function typeArray(a:Array, c:Class):ArrayCollection
		{
			if (!a) return null;
			var result:ArrayCollection = new ArrayCollection();
			for each(var o:Object in a)
			{
				result.addItem(typeObject(o, c));
			}
			return result;
		}
		
		private function typeObject(o:Object, c:Class):Object
		{
			var instance:Object = new c();
			var entity:Entity = map[c];
			var a:Association = null;
			
			var superEntity:Entity = entity.superEntity;
			if (superEntity)
			{
				var superInstance:Object = loadItem(superEntity.cls, o[entity.identity.property]);
				for each(var sf:Field in superEntity.fields)
				{
					instance[sf.property] = superInstance[sf.property];
				}
				for each(a in superEntity.manyToOneAssociations)
				{
					instance[a.property] = superInstance[a.property];
				}
				for each(a in superEntity.oneToManyAssociations)
				{
					instance[a.property] = superInstance[a.property];
				}
				for each(a in superEntity.manyToManyAssociations)
				{
					instance[a.property] = superInstance[a.property];
				}
			}
			
			for each(var f:Field in entity.fields)
			{
				instance[f.property] = o[f.column];
			}
			
			setCachedValue(instance);
			
			for each(a in entity.manyToOneAssociations)
			{
				// remember that o is the data set returned from the database
				// not the object instance
				var id:int = o[a.column];
				if (id > 0)
				{
					var value:Object = null;
					if (a.inverse)
					{
						value = getCachedValue(a.associatedEntity.cls, id);
					}
					if (value == null)
					{
						value = loadItem(a.associatedEntity.cls, id);
					}
					instance[a.property] = value;
				}
			}
			for each(var otmAssoc:OneToManyAssociation in entity.oneToManyAssociations)
			{
				if (otmAssoc.lazy)
				{
					instance[otmAssoc.property] = new LazyList(this, otmAssoc, o[entity.identity.property]);
				}
				else
				{
					instance[otmAssoc.property] = selectOneToManyAssociation(otmAssoc.column, otmAssoc.associatedEntity.cls, otmAssoc.selectCommand, o[entity.identity.property]);
				}
			}
			for each(var mtmAssoc:ManyToManyAssociation in entity.manyToManyAssociations)
			{
				if (mtmAssoc.lazy)
				{
					instance[mtmAssoc.property] = new LazyList(this, mtmAssoc, o[entity.identity.property]);
				}
				else
				{
					instance[mtmAssoc.property] = selectManyToManyAssociation(mtmAssoc.column, mtmAssoc.associatedEntity.cls, mtmAssoc.selectCommand, o[entity.identity.property]);
				}
			}
			return instance;
		}
		
		private function selectOneToManyAssociation(fkColumn:String, c:Class, command:SelectCommand, id:int):ArrayCollection
		{
			command.setParam(fkColumn, id);
			command.execute();
			return typeArray(command.result, c);
		}
		
		private function selectManyToManyAssociation(fkColumn:String, c:Class, command:SelectManyToManyCommand, id:int):ArrayCollection
		{
			command.setParam(fkColumn, id);
			command.execute();
			return typeArray(command.result, c);
		}
		
		private function getCache(c:Class):Object
		{
			var cachedObject:Object = cache[c];
			if (!cachedObject)
			{
				cachedObject = new Object();
				cache[c] = cachedObject;
			}
			return cachedObject;
		}
		
		private function getCachedValue(c:Class, id:int):Object
		{
			return getCache(c)[id];
		}
		
		private function setCachedValue(o:Object):void
		{
			var c:Class = Class(getDefinitionByName(getQualifiedClassName(o)));
			getCache(c)[o[map[c].identity.property]] = o;
		}

	}
}