package nz.co.codec.flexorm.command
{
	import flash.data.SQLColumnSchema;
	import flash.data.SQLConnection;
	import flash.data.SQLSchemaResult;
	import flash.data.SQLStatement;
	import flash.data.SQLTableSchema;
	import flash.errors.SQLError;
	
	import mx.collections.ArrayCollection;
	
	public class CreateCommand extends SQLCommand
	{
		private var pk:String;
		
		private var created:Boolean = false;
		
		public function CreateCommand(table:String, sqlConnection:SQLConnection)
		{
			super(table, sqlConnection);
			changed = true;
		}
		
		public function setPk(column:String):void
		{
			pk = column + " integer primary key autoincrement";
			changed = true;
		}
		
		override public function addColumn(column:String, type:String):void
		{
			if (!columns)
			{
				columns = new Object();
			}
			columns[column] = { type: type, constraint: null };
			changed = true;
		}
		
		public function addFkColumn(
			column:String,
			type:String,
			fkConstraintTable:String,
			fkConstraintColumn:String):void
		{
			if (!columns)
			{
				columns = new Object();
			}
			columns[column] = { type: type, constraint: { table: fkConstraintTable, column: fkConstraintColumn } };
			changed = true;
		}
		
		override protected function prepareStatement():void
		{
			var createSQL:String = "";
			var column:String = null;
			var existingColumns:ArrayCollection = getExistingColumns();
			if (existingColumns)
			{
				created = true;
				for (column in columns)
				{
					if (!existingColumns.contains(column))
					{
						createSQL += "alter table " + _table +
							" add " + column + " " + columns[column].type + ";";
					}
				}
			}
			else
			{
				createSQL = "create table if not exists " + _table
					+ " (";
				if (pk) createSQL += pk + ",";
				for (column in columns)
				{
					createSQL += column + " " + columns[column].type + ",";
				}
				// remove last comma
				createSQL = createSQL.substring(0, createSQL.length - 1) + ")";
			}
			_statement.text = createSQL;
			changed = false;
		}
		
		override public function execute():void
		{
			if (changed) prepareStatement();
			if (_statement.text == "") return;
			if (debugLevel > 0) debug();
			_statement.execute();
			
			if (!created)
			{
				// create foreign key constraint triggers
				for (var column:String in columns)
				{
					var constraint:Object = columns[column].constraint;
					if (constraint)
					{
						createFkConstraintInsertTrigger(column, constraint);
						createFkConstraintUpdateTrigger(column, constraint);
						createFkConstraintDeleteTrigger(column, constraint);
					}
				}
			}
		}
		
		private function createFkConstraintInsertTrigger(column:String, constraint:Object):void
		{
			var triggerStatement:SQLStatement = new SQLStatement();
			triggerStatement.sqlConnection = _sqlConnection;
			var triggerSQL:String = "create trigger fki_" + _table + "_" + column +
				" before insert on " + _table +
				" for each row begin" +
				" select raise(rollback, 'insert on table \"" + _table +
				"\" violates foreign key constraint \"fki_" + _table + "_" + column + "\"')" +
				" where new." + column + " is not null and new." + column +
				" <> 0 and (select " + constraint.column + " from " + constraint.table +
				" where " + constraint.column + " = new." + column + ") is null; end;";
			triggerStatement.text = triggerSQL;
			if (debugLevel > 0)
			{
				trace(triggerSQL);
			}
			triggerStatement.execute();
		}
		
		private function createFkConstraintUpdateTrigger(column:String, constraint:Object):void
		{
			var triggerStatement:SQLStatement = new SQLStatement();
			triggerStatement.sqlConnection = _sqlConnection;
			var triggerSQL:String = "create trigger fku_" + _table + "_" + column +
				" before update on " + _table +
				" for each row begin" +
				" select raise(rollback, 'update on table \"" + _table +
				"\" violates foreign key constraint \"fku_" + _table + "_" + column + "\"')" +
				" where new." + column + " is not null and new." + column +
				" <> 0 and (select " + constraint.column + " from " + constraint.table +
				" where " + constraint.column + " = new." + column + ") is null; end;";
			triggerStatement.text = triggerSQL;
			if (debugLevel > 0)
			{
				trace(triggerSQL);
			}
			triggerStatement.execute();
		}
		
		private function createFkConstraintDeleteTrigger(column:String, constraint:Object):void
		{
			var triggerStatement:SQLStatement = new SQLStatement();
			triggerStatement.sqlConnection = _sqlConnection;
			var triggerSQL:String = "create trigger fkd_" + _table + "_" + column +
				" before delete on " + constraint.table +
				" for each row begin" +
				" select raise(rollback, 'delete on table \"" + constraint.table +
				"\" violates foreign key constraint \"fkd_" + _table + "_" + column + "\"')" +
				" where (select " + column + " from " + _table +
				" where " + column + " = old." + constraint.column + ") is not null; end;";
			triggerStatement.text = triggerSQL;
			if (debugLevel > 0)
			{
				trace(triggerSQL);
			}
			triggerStatement.execute();
		}
		
		private function getExistingColumns():ArrayCollection
		{
			try
			{
				_sqlConnection.loadSchema(SQLTableSchema, _table);
				var schemaResult:SQLSchemaResult = _sqlConnection.getSchemaResult();
				if (schemaResult.tables.length > 0)
				{
					var existingColumns:ArrayCollection = new ArrayCollection();
					for each(var col:SQLColumnSchema in schemaResult.tables[0].columns)
					{
						if (!col.primaryKey)
						{
							existingColumns.addItem(col.name);
						}
					}
					return existingColumns;
				}
			}
			catch (error:SQLError) { }
			return null;
		}
		
		public function toString():String
		{
			return "CREATE " + _table + ": " + _statement.text;
		}

	}
}