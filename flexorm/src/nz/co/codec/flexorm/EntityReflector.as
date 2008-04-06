package nz.co.codec.flexorm
{
	import flash.data.SQLConnection;
	import flash.utils.describeType;
	import flash.utils.getDefinitionByName;
	
	import nz.co.codec.flexorm.command.CreateCommand;
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
	
	public class EntityReflector
	{
		private var map:Object;
		
		private var sqlConnection:SQLConnection;
		
		private var deferred:Array;
		
		private var buildSQLQueue:Array;
		
		private var _debugLevel:int = 0;
		
		public function EntityReflector(map:Object, sqlConnection:SQLConnection)
		{
			this.map = map;
			this.sqlConnection = sqlConnection;
			deferred = new Array();
			buildSQLQueue = new Array();
		}
		
		public function set debugLevel(value:int):void
		{
			_debugLevel = value;
		}
		
		public function get debugLevel():int
		{
			return _debugLevel;
		}
		
		internal function loadMetadata(c:Class):Entity
		{
			var entity:Entity = loadMetadataForClass(c);
			
			while (deferred.length > 0)
			{
				loadMetadataForClass(deferred.pop());
			}
			
			while (buildSQLQueue.length > 0)
			{
				buildSQLCommands(buildSQLQueue.pop());
			}
			
			return entity;
		}
		
		private function loadMetadataForClass(c:Class):Entity
		{
			var entity:Entity = map[c];
			if (!entity)
			{
				entity = new Entity(c);
				map[c] = entity;
			}
			var xml:XML = describeType(new c());
			entity.table = xml.metadata.(@name == "Table").arg.(@key == "name").@value;
			var table:String = entity.table;
			
			var superType:String = xml.extendsClass[0].@type.toString();
			if (superType != "Object")
			{
				var superClass:Class = getClass(superType);
				var superEntity:Entity = map[superClass];
				if (!superEntity)
				{
					superEntity = new Entity(superClass);
					map[superClass] = superEntity;
					deferred.push(superClass);
				}
				entity.superEntity = superEntity;
			}
			
			var variables:XMLList = xml.accessor;
			for each(var v:Object in variables)
			{
				// skip properties of superclass
				var declaredBy:String = v.@declaredBy.toString();
				if (declaredBy.search(new RegExp(entity.classname, "i")) == -1)
				{
					continue;
				}
				
				var property:String = v.@name.toString();
				var column:String = null;
				var type:Class = null; // associated object class
				var associatedEntity:Entity = null;
				var cascadeType:String = null;
				
				if (v.metadata.(@name == "Column").length() > 0)
				{
					column = v.metadata.(@name == "Column").arg.(@key == "name").@value.toString();
					entity.addField(new Field({ property: property, column: column, type: getSQLType(v.@type) }));
				}
				
				else if (v.metadata.(@name == "ManyToOne").length() > 0)
				{
					column = property + "Id";
					type = getClass(v.@type);
					cascadeType = v.metadata.(@name == "OneToMany").arg.(@key == "cascade").@value;
					var inverse:Boolean = Boolean(v.metadata.(@name == "ManyToOne").arg.(@key == "inverse").@value.toString());
					associatedEntity = map[type];
					if (!associatedEntity)
					{
						associatedEntity = new Entity(type);
						map[type] = associatedEntity;
						deferred.push(type);
					}
					entity.addManyToOneAssociation(new Association({
						property: property,
						column: column,
						associatedEntity: associatedEntity,
						inverse: inverse,
						cascadeType: cascadeType
					}));
				}
				
				else if (v.metadata.(@name == "OneToMany").length() > 0)
				{
					column = entity.fkColumn;
					type = getClass(v.metadata.(@name == "OneToMany").arg.(@key == "type").@value);
					cascadeType = v.metadata.(@name == "OneToMany").arg.(@key == "cascade").@value;
					associatedEntity = map[type];
					var otmAssociation:OneToManyAssociation = null;
					if (associatedEntity)
					{
						otmAssociation = new OneToManyAssociation({
							property: property,
							column: column,
							associatedEntity: associatedEntity,
							cascadeType: cascadeType
						});
					}
					else
					{
						associatedEntity = new Entity(type);
						map[type] = associatedEntity;
						deferred.push(type);
						otmAssociation = new OneToManyAssociation({
							property: property,
							column: column,
							associatedEntity: associatedEntity,
							cascadeType: cascadeType
						});
					}
					associatedEntity.addOneToManyInverseAssociation(otmAssociation);
					entity.addOneToManyAssociation(otmAssociation);
				}
				
				else if (v.metadata.(@name == "ManyToMany").length() > 0)
				{
					column = entity.fkColumn;
					cascadeType = v.metadata.(@name == "ManyToMany").arg.(@key == "cascade").@value;
					type = getClass(v.metadata.(@name == "ManyToMany").arg.(@key == "type").@value);
					var associationTable:String = entity.classname + "_" + getClassName(type);
					associatedEntity = map[type];
					var joinColumn:String = getFkColumn(type);
					var mtmAssociation:ManyToManyAssociation = null;
					
					if (associatedEntity)
					{
						mtmAssociation = new ManyToManyAssociation({
							property: property,
							column: column,
							associationTable: associationTable,
							joinColumn: joinColumn,
							associatedEntity: associatedEntity,
							cascadeType: cascadeType
						});
					}
					else
					{
						associatedEntity = new Entity(type);
						map[type] = associatedEntity;
						deferred.push(type);
						mtmAssociation = new ManyToManyAssociation({
							property: property,
							column: column,
							associationTable: associationTable,
							joinColumn: joinColumn,
							associatedEntity: associatedEntity,
							cascadeType: cascadeType
						});
					}
					associatedEntity.addManyToManyInverseAssociation(mtmAssociation);
					entity.addManyToManyAssociation(mtmAssociation);
				}
				
				else if (v.metadata.(@name == "Transient").length() > 0)
				{
					// skip
				}
				
				else
				{
					column = property;
					entity.addField(new Field({ property: property, column: column, type: getSQLType(v.@type) }));
				}
				
				if (v.metadata.(@name == "Id").length() > 0)
				{
					entity.identity = new Identity({ property: property, column: column });
				}
			}
			entity.initialisationComplete = true;
			buildSQLQueue.push(entity);
			return entity;
		}
		
		private function buildSQLCommands(entity:Entity):void
		{
			var table:String = entity.table;
			
			var findAllCommand:FindAllCommand = new FindAllCommand(table, sqlConnection);
			var selectCommand:SelectCommand = new SelectCommand(table, sqlConnection);
			var insertCommand:InsertCommand = new InsertCommand(table, sqlConnection);
			var updateCommand:UpdateCommand = new UpdateCommand(table, sqlConnection);
			var deleteCommand:DeleteCommand = new DeleteCommand(table, sqlConnection);
			var createCommand:CreateCommand = new CreateCommand(table, sqlConnection);
			
			findAllCommand.debugLevel = _debugLevel;
			selectCommand.debugLevel = _debugLevel;
			insertCommand.debugLevel = _debugLevel;
			updateCommand.debugLevel = _debugLevel;
			deleteCommand.debugLevel = _debugLevel;
			createCommand.debugLevel = _debugLevel;
			
			var identity:Identity = entity.identity;
			
			selectCommand.addFilter(identity.column, identity.property);
			updateCommand.addFilter(identity.column, identity.property);
			deleteCommand.addFilter(identity.column, identity.property);
			
			if (entity.superEntity)
			{
				insertCommand.addColumn(identity.column, identity.property);
				createCommand.addColumn(identity.column, "integer");
			}
			else
			{
				createCommand.setPk(identity.column);
			}
			
			for each(var f:Field in entity.fields)
			{
				if (f.property != identity.property)
				{
					insertCommand.addColumn(f.column, f.property);
					updateCommand.addColumn(f.column, f.property);
					createCommand.addColumn(f.column, f.type);
				}
			}
			
			for each(var a:Association in entity.manyToOneAssociations)
			{
				insertCommand.addColumn(a.column, a.column);
				updateCommand.addColumn(a.column, a.column);
				createCommand.addColumn(a.column, "integer");
			}
			
			var otmAssoc:OneToManyAssociation = null;
			for each(otmAssoc in entity.oneToManyAssociations)
			{
				var otmSelectCommand:SelectCommand = new SelectCommand(otmAssoc.associatedEntity.table, sqlConnection);
				otmSelectCommand.debugLevel = _debugLevel;
				otmSelectCommand.addFilter(otmAssoc.column, otmAssoc.column);
				otmAssoc.selectCommand = otmSelectCommand;
			}
			for each(otmAssoc in entity.oneToManyInverseAssociations)
			{
				insertCommand.addColumn(otmAssoc.column, otmAssoc.column);
				updateCommand.addColumn(otmAssoc.column, otmAssoc.column);
				createCommand.addColumn(otmAssoc.column, "integer");
			}
			
			var mtmAssoc:ManyToManyAssociation = null;
			for each(mtmAssoc in entity.manyToManyAssociations)
			{
				var associationTable:String = mtmAssoc.associationTable;
				var associatedEntity:Entity = mtmAssoc.associatedEntity;
				var joinColumn:String = mtmAssoc.joinColumn;
				var column:String = mtmAssoc.column;
				
				var mtmSelectCommand:SelectManyToManyCommand = new SelectManyToManyCommand(associatedEntity.table, associationTable, associatedEntity.fkColumn, associatedEntity.identity.column, sqlConnection);
				mtmSelectCommand.debugLevel = _debugLevel;
				mtmSelectCommand.addFilter(column, column);
				
				var selectIndicesCommand:SelectManyToManyIndicesCommand = new SelectManyToManyIndicesCommand(associationTable, joinColumn, sqlConnection);
				selectIndicesCommand.debugLevel = _debugLevel;
				selectIndicesCommand.addFilter(column, column);
				
				var mtmInsertCommand:InsertCommand = new InsertCommand(associationTable, sqlConnection);
				mtmInsertCommand.debugLevel = _debugLevel;
				mtmInsertCommand.addColumn(column, column);
				mtmInsertCommand.addColumn(joinColumn, joinColumn);
				
				var mtmDeleteCommand:DeleteCommand = new DeleteCommand(associationTable, sqlConnection);
				mtmDeleteCommand.debugLevel = _debugLevel;
				mtmDeleteCommand.addFilter(column, column);
				mtmDeleteCommand.addFilter(joinColumn, joinColumn);
				
				mtmAssoc.selectIndicesCommand = selectIndicesCommand;
				mtmAssoc.selectCommand = mtmSelectCommand;
				mtmAssoc.insertCommand = mtmInsertCommand;
				mtmAssoc.deleteCommand = mtmDeleteCommand;
				
				var mtmCreateCommand:CreateCommand = new CreateCommand(associationTable, sqlConnection);
				mtmCreateCommand.debugLevel = _debugLevel;
				mtmCreateCommand.addColumn(column, "integer"); // column is entity.fkColumn
				mtmCreateCommand.addColumn(associatedEntity.fkColumn, "integer");
				mtmCreateCommand.execute();
			}
			entity.findAllCommand = findAllCommand;
			entity.selectCommand = selectCommand;
			entity.insertCommand = insertCommand;
			entity.updateCommand = updateCommand;
			entity.deleteCommand = deleteCommand;
			
			// create database schema for entity
			createCommand.execute();
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

	}
}