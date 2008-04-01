package nz.co.codec.flexorm
{
	import flash.data.SQLConnection;
	import flash.filesystem.File;
	import flash.utils.describeType;
	import flash.utils.getDefinitionByName;
	import flash.utils.getQualifiedClassName;
	
	import mx.collections.ArrayCollection;
	
	public class EntityManager
	{
		private static var _instance:EntityManager;
		
		private static var localInstantiation:Boolean = false;
		
		public static function get instance():EntityManager
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
		 * map is a nested hash, which holds the metadata for an entity. It
		 * may contain:
		 * 
		 * anonymous object for each entity class
		 * 
		 *   table:    database table name; defaults to entity class name
		 * 
		 *   identity: info about the id property of the entity
		 * 
		 *     column: database column name
		 * 
		 *     field:  property name
		 * 
		 *   manyToOneAssociations
		 *     anonymous object
		 * 
		 *       association: association property name
		 * 
		 *       column: database column name of FK in table of associated
		 *             entity (= class name of owning entity + 'Id', e.g.
		 *             'contactId')
		 * 
		 *       type: class of associated entity
		 * 
		 *       inverse: true or false if this association is the inverse
		 *             end of a bidirectional one-to-many association
		 * 
		 *       cascade: valid values are "save-update" (save or update
		 *             the associated entities on save of the owning entity),
		 *             "delete" (delete the associated entities on deletion
		 *             of the owning entity), "all" (support cascade save,
		 *             update, and delete), and "none" (do not cascade any
		 *             changes to the associated entities)
		 * 
		 *   oneToManyAssociations
		 *     anonymous object
		 * 
		 *       association: association property name
		 * 
		 *       column: database column name of FK in table of associated
		 *             entity (= class name of owning entity + 'Id', e.g.
		 *             'contactId')
		 * 
		 *       type: class of associated entity
		 * 
		 *       cascade: valid values are "save-update" (save or update
		 *             the associated entities on save of the owning entity),
		 *             "delete" (delete the associated entities on deletion
		 *             of the owning entity), "all" (support cascade save,
		 *             update, and delete), and "none" (do not cascade any
		 *             changes to the associated entities)
		 * 
		 *       command: an instance of SelectOneToManyCommand to select
		 *             the associated entities using the id value of the
		 *             owning entity as a parameter to the FK in the
		 *             'where clause'
		 * 
		 *   oneToManyInverseAssociations
		 *     anonymous object: a copy of the oneToManyAssociation set on
		 *             the map of the associated entity
		 * 
		 *       association: association property name
		 * 
		 *       column: database column name of FK in table of associated
		 *             entity (= class name of owning entity + 'Id', e.g.
		 *             'contactId')
		 * 
		 *       type: class of associated entity
		 * 
		 *       cascade: valid values are "save-update" (save or update
		 *             the associated entities on save of the owning entity),
		 *             "delete" (delete the associated entities on deletion
		 *             of the owning entity), "all" (support cascade save,
		 *             update, and delete), and "none" (do not cascade any
		 *             changes to the associated entities)
		 * 
		 *       command: an instance of SelectOneToManyCommand to select
		 *             the associated entities using the id value of the
		 *             owning entity as a parameter to the FK in the
		 *             'where clause'
		 * 
		 *   manyToManyAssociations
		 *     anonymous object
		 * 
		 *       association: association property name
		 * 
		 *       column: database column name of the FK in the association
		 *             table which links to the owning entity
		 * 
		 *       fkColumn: database column name of the FK in the association
		 *             table which links to the associated entity
		 * 
		 *       type: class of associated entity
		 * 
		 *       table: association table name
		 * 
		 *       cascade: valid values are "save-update" (save or update
		 *             the associated entities on save of the owning entity),
		 *             "delete" (delete the associated entities on deletion
		 *             of the owning entity), "all" (support cascade save,
		 *             update, and delete), and "none" (do not cascade any
		 *             changes to the associated entities)
		 * 
		 *       insertManyToManyCommand: an instance of
		 *             InsertManyToManyCommand which creates a row in the
		 *             association table to create a link across the
		 *             many-to-many relationship
		 * 
		 *       selectManyToManyIndicesCommand: an instance of
		 *             SelectManyToManyIndicesCommand to select the FK values
		 *             relating to the list of associated entities
		 * 
		 *       deleteManyToManyCommand: an instance of
		 *             DeleteManyToManyCommand to remove a many-to-many
		 *             association (not the associated entity)
		 * 
		 *       selectManyToManyCommand: an instance of
		 *             SelectOneToManyCommand to select the associated
		 *             entities using the id value of the owning entity
		 *             as a parameter to the FK in the 'where clause'
		 * 
		 *   complete: flag to indicate whether the loading of metadata
		 *             for an entity has been completed
		 */
		private var map:Object = new Object();
		
		private var deferred:Array = new Array();
		
		private var cache:Object = new Object();
		
		private var _sqlConnection:SQLConnection;
		
		public function EntityManager()
		{
			if (!localInstantiation)
			{
				throw new Error("EntityManager is a singleton. Use EntityManager.instance");
			}
		}
		
		public function findAll(c:Class):ArrayCollection
		{
			if (!map[c] || !map[c].complete) loadMetadata(c);
			var command:FindAllCommand = map[c].findAllCommand;
			command.execute();
			return typeArray(command.result, c);
		}
		
		public function loadItem(c:Class, id:int):Object
		{
			if (!map[c] || !map[c].complete) loadMetadata(c);
			var command:SelectCommand = map[c].selectCommand;
			command.setParam("id", id);
			command.execute();
			var result:Array = command.result;
			return (result) ? typeObject(result[0], c) : null;
		}
		
		public function save(o:Object, join:Object = null, insertManyToManyCommand:InsertCommand = null):void
		{
			if (o == null) return;
			var c:Class = Class(getDefinitionByName(getQualifiedClassName(o)));
			if (!map[c] || !map[c].complete) loadMetadata(c);
			var identity:Object = map[c].identity;
			var column:String = getFkColumn(c); // FK of this class c
			var id:int = o[identity.field]; // id value of this object o
			
			for each(var assoc:Object in map[c].manyToOneAssociations)
			{
				if (!assoc.inverse &&
					(assoc.cascade == CascadeType.SAVE_UPDATE || assoc.cascade == CascadeType.ALL) &&
					o[assoc.association])
				{
					save(o[assoc.association]);
				}
			}
			
			if (id > 0)
			{
				updateItem(o, c, join, insertManyToManyCommand);
			}
			else
			{
				createItem(o, c, join, insertManyToManyCommand);
			}
			id = o[identity.field]; // update for created items
			
			for each(var a:Object in map[c].oneToManyAssociations)
			{
				if (a.cascade == CascadeType.SAVE_UPDATE || a.cascade == CascadeType.ALL)
				{
					for each(var item:Object in o[a.association])
					{
						save(item, { column: column, id: id });
					}
				}
			}
			
			for each(var m:Object in map[c].manyToManyAssociations)
			{
				var selectCmd:SelectManyToManyIndicesCommand = m.selectManyToManyIndicesCommand;
				selectCmd.setParam(column, id);
				selectCmd.execute();
				var preIndices:Array = new Array();
				for each(var row:Object in selectCmd.result)
				{
					preIndices.push(row.roleId);
				}
				var idField:String = map[m.type].identity.field;
				for each(var i:Object in o[m.association])
				{
					var idx:int = preIndices.indexOf(i[idField]);
					if (idx > -1)
					{
						// no need to update associationTable
						if (a.cascade == CascadeType.SAVE_UPDATE || a.cascade == CascadeType.ALL)
						{
							save(i, { column: column, id: id });
						}
						preIndices.splice(idx, 1);
					}
					else
					{
						// insert link in associationTable
						if (a.cascade == CascadeType.SAVE_UPDATE || a.cascade == CascadeType.ALL)
						{
							save(i, { column: column, id: id }, m.insertManyToManyCommand);
						}
						else // just create the link instead
						{
							var insertManyToManyCommand:InsertCommand = m.insertManyToManyCommand;
							insertManyToManyCommand.setParam(m.fkColumn, i[map[m.type].identity.field]);
							insertManyToManyCommand.setParam(column, id);
							insertManyToManyCommand.execute();
						}
					}
				}
				// for each pre index left
				for each(var j:int in preIndices)
				{
					// delete link from associationTable
					var deleteCmd:DeleteManyToManyCommand = m.deleteManyToManyCommand;
					deleteCmd.setParam(column, id);
					deleteCmd.setParam(m.fkColumn, j);
					deleteCmd.execute();
				}
			}
		}
		
		private function updateItem(o:Object, c:Class, join:Object = null, insertManyToManyCommand:InsertCommand = null):void
		{
			var command:UpdateCommand = map[c].updateCommand;
			for each(var f:Object in map[c].fields)
			{
				command.setParam(f.field, o[f.field]);
			}
			for each(var a:Object in map[c].manyToOneAssociations)
			{
				if (o[a.association])
				{
					command.setParam(a.column, o[a.association][map[a.type].identity.field]);
				}
				else
				{
					command.setParam(a.column, 0);
				}
			}
			if (join && !insertManyToManyCommand) command.setParam(join.column, join.id);
			command.execute();
			if (join && insertManyToManyCommand)
			{
				insertManyToManyCommand.setParam(getFkColumn(c), o[map[c].identity.field]);
				insertManyToManyCommand.setParam(join.column, join.id);
				insertManyToManyCommand.execute();
			}
		}
		
		private function createItem(o:Object, c:Class, join:Object = null, insertManyToManyCommand:InsertCommand = null):void
		{
			var command:InsertCommand = map[c].insertCommand;
			var identity:Object = map[c].identity;
			for each(var f:Object in map[c].fields)
			{
				var field:String = f.field;
				if (field != identity.field)
				{
					command.setParam(field, o[field]);
				}
			}
			for each(var a:Object in map[c].manyToOneAssociations)
			{
				if (o[a.association])
				{
					command.setParam(a.column, o[a.association][map[a.type].identity.field]);
				}
				else
				{
					command.setParam(a.column, null);
				}
			}
			if (join && !insertManyToManyCommand) command.setParam(join.column, join.id);
			command.execute();
			o[identity.field] = command.lastInsertRowID;
			
			if (join && insertManyToManyCommand)
			{
				insertManyToManyCommand.setParam(getFkColumn(c), command.lastInsertRowID);
				insertManyToManyCommand.setParam(join.column, join.id)
				insertManyToManyCommand.execute();
			}
		}
		
		public function remove(o:Object):void
		{
			var c:Class = Class(getDefinitionByName(getQualifiedClassName(o)));
			if (!map[c] || !map[c].complete) loadMetadata(c);
			
			for each(var a1:Object in map[c].oneToManyAssociations)
			{
				if (a1.cascade == CascadeType.DELETE || a1.cascade == CascadeType.ALL)
				{
					for each(var i1:Object in o[a1.association])
					{
						remove(i1);
					}
				}
			}
			
			// Doesn't make sense to support cascade delete on many-to-many associations
			
			var command:DeleteCommand = map[c].deleteCommand;
			var identity:Object = map[c].identity;
			command.setParam(identity.field, o[identity.field]);
			command.execute();
			
			for each(var a:Object in map[c].manyToOneAssociations)
			{
				if (o[a.association] &&
					(a.cascade == CascadeType.DELETE || a.cascade == CascadeType.ALL))
				{
					remove(o[a.association]);
				}
			}
		}
		
		private function loadMetadata(c:Class):void
		{
			loadMetadataForClass(c);
			while (deferred.length > 0)
			{
				loadMetadataForClass(deferred.pop());
			}
		}
		
		private function loadMetadataForClass(c:Class):void
		{
			if (!map[c])
			{
				map[c] = new Object();
				map[c].complete = false;
			}
			var xml:XML = describeType(new c());
			var table:String = xml.metadata.(@name == "Table").arg.(@key == "name").@value;
			if (!table) table = getClassName(c);
			map[c].table = table;
			
			var createCommand:CreateCommand = new CreateCommand(table, sqlConnection);
			var findAllCommand:FindAllCommand = new FindAllCommand(table, sqlConnection);
			var selectCommand:SelectCommand = new SelectCommand(table, sqlConnection);
			var insertCommand:InsertCommand = new InsertCommand(table, sqlConnection);
			var updateCommand:UpdateCommand = new UpdateCommand(table, sqlConnection);
			var deleteCommand:DeleteCommand = new DeleteCommand(table, sqlConnection);
			
			map[c].fields = new ArrayCollection();
			map[c].manyToOneAssociations = new ArrayCollection();
			map[c].oneToManyAssociations = new ArrayCollection();
			map[c].manyToManyAssociations = new ArrayCollection();
			
			var variables:XMLList = xml.accessor;
			for each(var v:Object in variables)
			{
				var field:String = v.@name.toString();
				var column:String = null;
				var cascade:String = null;
				
				if (v.metadata.(@name == "Column").length() > 0)
				{
					column = v.metadata.(@name == "Column").arg.(@key == "name").@value.toString();
					map[c].fields.addItem({ field: field, column: column });
				}
				else if (v.metadata.(@name == "ManyToOne").length() > 0)
				{
					var inverse:Boolean = Boolean(v.metadata.(@name == "ManyToOne").arg.(@key == "inverse").@value.toString());
					cascade = v.metadata.(@name == "OneToMany").arg.(@key == "cascade").@value;
					if (cascade == "") cascade = CascadeType.SAVE_UPDATE;
					column = field + "Id";
					map[c].manyToOneAssociations.addItem({
						association: field,
						column: column,
						type: getClass(v.@type),
						inverse: inverse,
						cascade: cascade
					});
				}
				else if (v.metadata.(@name == "OneToMany").length() > 0)
				{
					column = getFkColumn(c);
					var type:Class = getClass(v.metadata.(@name == "OneToMany").arg.(@key == "type").@value);
					cascade = v.metadata.(@name == "OneToMany").arg.(@key == "cascade").@value;
					if (cascade == "") cascade = CascadeType.SAVE_UPDATE;
					var association:Object = null;
					if (!map[type])
					{
						map[type] = new Object();
						map[type].complete = false;
						deferred.push(type);
						map[type].oneToManyInverseAssociations = new ArrayCollection();
						association = {
							association: field,
							column: column,
							type: type,
							cascade: cascade
						};
					}
					else
					{
						if (!map[type].oneToManyInverseAssociations)
						{
							map[type].oneToManyInverseAssociations = new ArrayCollection();
						}
						var selectOneToManyCommand:SelectCommand = new SelectCommand(map[type].table, sqlConnection);
						selectOneToManyCommand.setIdColumn(column, column);
						association = {
							association: field,
							column: column,
							type: type,
							cascade: cascade,
							command: selectOneToManyCommand
						};
						
						map[type].createCommand.addColumn(column, "integer");
						map[type].insertCommand.addColumn(column, column);
						map[type].updateCommand.addColumn(column, column);
					}
					map[type].oneToManyInverseAssociations.addItem(association);
					map[c].oneToManyAssociations.addItem(association);
				}
				else if (v.metadata.(@name == "ManyToMany").length() > 0)
				{
					column = getFkColumn(c);
					var t:Class = getClass(v.metadata.(@name == "ManyToMany").arg.(@key == "type").@value);
					cascade = v.metadata.(@name == "ManyToMany").arg.(@key == "cascade").@value;
					if (cascade == "") cascade = CascadeType.SAVE_UPDATE;
					var associationTable:String = getClassName(c) + "_" + getClassName(t);
					var fkColumn:String = getFkColumn(t);
					var massoc:Object = null;
					
					var insertManyToManyCommand:InsertCommand = new InsertCommand(associationTable, sqlConnection);
					insertManyToManyCommand.addColumn(column, column);
					insertManyToManyCommand.addColumn(fkColumn, fkColumn);
					
					var selectManyToManyIndicesCommand:SelectManyToManyIndicesCommand = new SelectManyToManyIndicesCommand(associationTable, fkColumn, sqlConnection);
					selectManyToManyIndicesCommand.setIdColumn(column, column);
					
					var deleteManyToManyCommand:DeleteManyToManyCommand = new DeleteManyToManyCommand(associationTable, sqlConnection);
					deleteManyToManyCommand.setIdColumn(column, column);
					deleteManyToManyCommand.setFkColumn(fkColumn, fkColumn);
					
					if (!map[t])
					{
						map[t] = new Object();
						map[t].complete = false;
						deferred.push(t);
						map[t].manyToManyInverseAssociations = new ArrayCollection();
						massoc = {
							association: field,
							column: column,
							fkColumn: fkColumn,
							type: t,
							table: associationTable,
							cascade: cascade,
							insertManyToManyCommand: insertManyToManyCommand,
							selectManyToManyIndicesCommand: selectManyToManyIndicesCommand,
							deleteManyToManyCommand: deleteManyToManyCommand
						};
					}
					else
					{
						if (!map[t].manyToManyInverseAssociations)
						{
							map[t].manyToManyInverseAssociations = new ArrayCollection();
						}
						var selectManyToManyCommand:SelectManyToManyCommand = new SelectManyToManyCommand(map[t].table, associationTable, getFkColumn(t), map[t].identity.column, sqlConnection);
						selectManyToManyCommand.setIdColumn(column, column);
						massoc = {
							association: field,
							column: column,
							fkColumn: fkColumn,
							type: t,
							table: associationTable,
							cascade: cascade,
							insertManyToManyCommand: insertManyToManyCommand,
							selectManyToManyIndicesCommand: selectManyToManyIndicesCommand,
							deleteManyToManyCommand: deleteManyToManyCommand,
							selectManyToManyCommand: selectManyToManyCommand
						};
						
						var createManyToManyCommand:CreateCommand = new CreateCommand(associationTable, sqlConnection);
						createManyToManyCommand.addColumn(column, "integer");
						createManyToManyCommand.addColumn(getFkColumn(t), "integer");
						createManyToManyCommand.execute();
					}
					map[t].manyToManyInverseAssociations.addItem(massoc);
					map[c].manyToManyAssociations.addItem(massoc);
				}
				else if (v.metadata.(@name == "Transient").length() > 0)
				{
					// skip
				}
				else
				{
					column = field;
					map[c].fields.addItem({ field: field, column: column });
				}
				
				if (v.metadata.(@name == "Id").length() > 0)
				{
					map[c].identity = { field: field, column: column };
					createCommand.setIdColumn(column);
					selectCommand.setIdColumn(column, field);
					updateCommand.setIdColumn(column, field);
					deleteCommand.setIdColumn(column, field);
				}
				else if (v.metadata.(@name == "ManyToOne").length() > 0)
				{
					createCommand.addColumn(column, "integer");
					insertCommand.addColumn(column, column);
					updateCommand.addColumn(column, column);
				}
				else if (v.metadata.(@name == "OneToMany").length() > 0)
				{
					// do nothing
				}
				else if (v.metadata.(@name == "ManyToMany").length() > 0)
				{
					// do nothing
				}
				else if (v.metadata.(@name == "Transient").length() > 0)
				{
					// skip
				}
				else
				{
					createCommand.addColumn(column, getSQLType(v.@type));
					insertCommand.addColumn(column, field);
					updateCommand.addColumn(column, field);
				}
			}
			
			if (map[c].oneToManyInverseAssociations)
			{
				for each(var a:Object in map[c].oneToManyInverseAssociations)
				{
					if (!a.hasOwnProperty("command"))
					{
						var selectOneToManyCmd:SelectCommand = new SelectCommand(table, sqlConnection);
						selectOneToManyCmd.setIdColumn(a.column, a.column);
						a["command"] = selectOneToManyCmd;
					}
					
					createCommand.addColumn(a.column, "integer");
					insertCommand.addColumn(a.column, a.column);
					updateCommand.addColumn(a.column, a.column);
				}
			}
			
			if (map[c].manyToManyInverseAssociations)
			{
				for each(var m:Object in map[c].manyToManyInverseAssociations)
				{
					if (!m.hasOwnProperty("selectManyToManyCommand"))
					{
						var selectManyToManyCmd:SelectManyToManyCommand = new SelectManyToManyCommand(table, m.table, getFkColumn(c), map[c].identity.column, sqlConnection);
						selectManyToManyCmd.setIdColumn(m.column, m.column);
						m["selectManyToManyCommand"] = selectManyToManyCmd;
					}
					
					var createManyToManyCmd:CreateCommand = new CreateCommand(m.table, sqlConnection);
					createManyToManyCmd.addColumn(m.column, "integer");
					createManyToManyCmd.addColumn(getFkColumn(c), "integer");
					createManyToManyCmd.execute();
				}
			}
			
			map[c].findAllCommand = findAllCommand;
			map[c].selectCommand = selectCommand;
			map[c].insertCommand = insertCommand;
			map[c].updateCommand = updateCommand;
			map[c].deleteCommand = deleteCommand;
			
			createCommand.execute();
			
			map[c].complete = true;
		}
		
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
			for each(var f:Object in map[c].fields)
			{
				instance[f.field] = o[f.column];
			}
			setCachedValue(instance);
			for each(var a1:Object in map[c].manyToOneAssociations)
			{
				var id:int = o[a1.column];
				if (id > 0)
				{
					var value:Object = null;
					if (a1.inverse)
					{
						value = getCachedValue(a1.type, id);
					}
					if (value == null)
					{
						value = loadItem(a1.type, id);
					}
					instance[a1.association] = value;
				}
			}
			for each(var a2:Object in map[c].oneToManyAssociations)
			{
				instance[a2.association] = selectOneToManyAssociation(a2.column, a2.type, a2.command, o[map[c].identity.field]);
			}
			for each(var a3:Object in map[c].manyToManyAssociations)
			{
				instance[a3.association] = selectManyToManyAssociation(a3.column, a3.type, a3.selectManyToManyCommand, o[map[c].identity.field]);
			}
			return instance;
		}
		
		private function selectOneToManyAssociation(fkColumn:String, type:Class, command:SelectCommand, id:int):ArrayCollection
		{
			command.setParam(fkColumn, id);
			command.execute();
			return typeArray(command.result, type);
		}
		
		private function selectManyToManyAssociation(fkColumn:String, type:Class, command:SelectManyToManyCommand, id:int):ArrayCollection
		{
			command.setParam(fkColumn, id);
			command.execute();
			return typeArray(command.result, type);
		}
		
		private function getClass(asType:String):Class
		{
			return getDefinitionByName(asType) as Class;
		}
		
		private function getClassName(c:Class):String
		{
			var className:String = String(c);
			var len:int = className.length;
			var x:int = className.lastIndexOf(" ") + 1;
			return className.substr(x, 1).toLowerCase() +
				className.substring(x + 1, len - 1);
		}
		
		private function getFkColumn(c:Class):String
		{
			return getClassName(c) + "Id";
		}
		
		private function getSQLType(asType:String):String
		{
			switch (asType)
			{
				case "int" || "uint":
					return "integer";
					break;
				case "Number":
					return "real";
					break;
				case "Date":
					return "date";
					break;
				default:
					return "text";
			}
		}
		
		private function getCache(c:Class):Object
		{
			if (!cache[c]) cache[c] = new Object();
			return cache[c];
		}
		
		private function getCachedValue(c:Class, id:int):Object
		{
			return getCache(c)[id];
		}
		
		private function setCachedValue(o:Object):void
		{
			var c:Class = Class(getDefinitionByName(getQualifiedClassName(o)));
			getCache(c)[o[map[c].identity.field]] = o;
		}
		
		public function get sqlConnection():SQLConnection
		{
			if (!_sqlConnection)
			{
				var dbFile:File = File.applicationStorageDirectory.resolvePath("default.db");
				_sqlConnection = new SQLConnection();
				_sqlConnection.open(dbFile);
			}
			return _sqlConnection;
		}
		
		public function set sqlConnection(value:SQLConnection):void
		{
			_sqlConnection = value;
		}

	}
}