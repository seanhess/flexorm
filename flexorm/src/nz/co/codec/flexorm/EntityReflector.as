package nz.co.codec.flexorm
{
	import flash.data.SQLConnection;
	import flash.utils.describeType;
	import flash.utils.getDefinitionByName;
	
	import mx.utils.StringUtil;
	
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
		
		private var _debugLevel:int = 0;
		
		public function EntityReflector(map:Object, sqlConnection:SQLConnection)
		{
			this.map = map;
			this.sqlConnection = sqlConnection;
			deferred = [];
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
			var entities:Array = [];
			entities.push(entity);
			while (deferred.length > 0)
			{
				entities.push(loadMetadataForClass(deferred.pop()));
			}
			buildSQL(entities);
			createTables(sequenceEntitiesForTableCreation(entities));
			
			return entity;
		}
		
		private function buildSQL(entities:Array):void
		{
			for each(var entity:Entity in entities)
			{
				buildSQLCommands(entity);
			}
		}
		
		private function createTables(createSequence:Array):void
		{
			var associationTableCreateCommands:Array = [];
			for each(var entity:Entity in createSequence)
			{
				entity.createCommand.execute();
				for each(var a:ManyToManyAssociation in entity.manyToManyAssociations)
				{
					associationTableCreateCommands.push(a.createCommand);
				}
			}
			// create association tables last
			for each(var command:CreateCommand in associationTableCreateCommands)
			{
				command.execute();
			}
		}
		
		/**
		 * Sequence entities so that foreign key constraints are not violated
		 * as table are created.
		 */
		private function sequenceEntitiesForTableCreation(entities:Array):Array
		{
			var createSequence:Array = [].concat(entities);
			for each(var entity:Entity in entities)
			{
				var i:int = createSequence.indexOf(entity);
				var k:int = 0;
				for each(var e:Entity in entity.dependencies)
				{
					var j:int = createSequence.indexOf(e) + 1;
					k = (j > k) ? j : k;
				}
				if (k != i)
				{
					createSequence.splice(k, 0, entity);
					if (k < i)
					{
						createSequence.splice(i + 1, 1);
					}
					else
					{
						createSequence.splice(i, 1);
					}
				}
			}
			return createSequence;
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
				entity.addDependency(superEntity);
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
				var lazy:Boolean = false;
				var constrain:Boolean = true;
				var metadata:XMLList = null;
				
				if (v.metadata.(@name == "Column").length() > 0)
				{
					column = v.metadata.(@name == "Column").arg.(@key == "name").@value.toString();
					entity.addField(new Field({ property: property, column: column, type: getSQLType(v.@type) }));
				}
				
				else if (v.metadata.(@name == "ManyToOne").length() > 0)
				{
					metadata = v.metadata.(@name == "ManyToOne");
					column = property + "Id";
					type = getClass(v.@type);
					cascadeType = metadata.arg.(@key == "cascade").@value;
					constrain = parseBoolean(metadata.arg.(@key == "constrain").@value.toString(), true);
					var inverse:Boolean = parseBoolean(metadata.arg.(@key == "inverse").@value.toString(), false);
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
						cascadeType: cascadeType,
						constrain: constrain
					}));
					entity.addDependency(associatedEntity);
				}
				
				else if (v.metadata.(@name == "OneToMany").length() > 0)
				{
					metadata = v.metadata.(@name == "OneToMany");
					column = entity.fkColumn;
					type = getClass(metadata.arg.(@key == "type").@value);
					cascadeType = metadata.arg.(@key == "cascade").@value;
					lazy = parseBoolean(metadata.arg.(@key == "lazy").@value.toString(), false);
					constrain = parseBoolean(metadata.arg.(@key == "constrain").@value.toString(), true);
					associatedEntity = map[type];
					if (!associatedEntity)
					{
						associatedEntity = new Entity(type);
						map[type] = associatedEntity;
						deferred.push(type);
					}
					var otmAssociation:OneToManyAssociation = new OneToManyAssociation({
						property: property,
						column: column,
						associatedEntity: associatedEntity,
						cascadeType: cascadeType,
						lazy: lazy,
						constrain: constrain
					});
					associatedEntity.addOneToManyInverseAssociation(otmAssociation);
					entity.addOneToManyAssociation(otmAssociation);
					associatedEntity.addDependency(entity);
				}
				
				else if (v.metadata.(@name == "ManyToMany").length() > 0)
				{
					metadata = v.metadata.(@name == "ManyToMany");
					column = entity.fkColumn;
					cascadeType = metadata.arg.(@key == "cascade").@value;
					lazy = parseBoolean(metadata.arg.(@key == "lazy").@value.toString(), false);
					constrain = parseBoolean(metadata.arg.(@key == "constrain").@value.toString(), true);
					type = getClass(metadata.arg.(@key == "type").@value);
					var associationTable:String = entity.classname + "_" + getClassName(type);
					var joinColumn:String = getFkColumn(type);
					associatedEntity = map[type];
					if (!associatedEntity)
					{
						associatedEntity = new Entity(type);
						map[type] = associatedEntity;
						deferred.push(type);
					}
					var mtmAssociation:ManyToManyAssociation = new ManyToManyAssociation({
						property: property,
						column: column,
						associationTable: associationTable,
						joinColumn: joinColumn,
						associatedEntity: associatedEntity,
						cascadeType: cascadeType,
						lazy: lazy,
						constrain: constrain
					});
					associatedEntity.addManyToManyInverseAssociation(mtmAssociation);
					entity.addManyToManyAssociation(mtmAssociation);
					associatedEntity.addDependency(entity);
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
			return entity;
		}
		
		private function parseBoolean(str:String, defaultValue:Boolean):Boolean
		{
			if (!str) return defaultValue;
			switch (StringUtil.trim(str))
			{
				case "":
					return defaultValue;
					break;
				case "true":
					return true;
					break;
				case "false":
					return false;
					break;
				default:
					throw new Error("Cannot parse Boolean from '" + str + "'");
			}
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
				if (a.constrain)
				{
					createCommand.addFkColumn(a.column, "integer", a.associatedEntity.table, a.associatedEntity.identity.column);
				}
				else
				{
					createCommand.addColumn(a.column, "integer");
				}
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
				if (otmAssoc.constrain)
				{
					createCommand.addFkColumn(otmAssoc.column, "integer", otmAssoc.ownerEntity.table, otmAssoc.ownerEntity.identity.column);
				}
				else
				{
					createCommand.addColumn(otmAssoc.column, "integer");
				}
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
				
				// column is entity.fkColumn
				if (mtmAssoc.constrain)
				{
					mtmCreateCommand.addFkColumn(column, "integer", entity.table, identity.column);
					mtmCreateCommand.addFkColumn(associatedEntity.fkColumn, "integer",
						associatedEntity.table, associatedEntity.identity.column);
				}
				else
				{
					mtmCreateCommand.addColumn(column, "integer");
					mtmCreateCommand.addColumn(associatedEntity.fkColumn, "integer");
				}
				mtmAssoc.createCommand = mtmCreateCommand;
			}
			entity.findAllCommand = findAllCommand;
			entity.selectCommand = selectCommand;
			entity.insertCommand = insertCommand;
			entity.updateCommand = updateCommand;
			entity.deleteCommand = deleteCommand;
			entity.createCommand = createCommand;
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