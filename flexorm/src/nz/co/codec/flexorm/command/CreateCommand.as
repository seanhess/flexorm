package nz.co.codec.flexorm.command
{
    import flash.data.SQLColumnSchema;
    import flash.data.SQLConnection;
    import flash.data.SQLSchemaResult;
    import flash.data.SQLStatement;
    import flash.data.SQLTableSchema;
    import flash.errors.SQLError;

    import mx.collections.ArrayCollection;

    import nz.co.codec.flexorm.ICommand;

    public class CreateCommand extends SQLCommand
    {
        private var _pk:String;

        private var _created:Boolean = false;

        public function CreateCommand(table:String, sqlConnection:SQLConnection, debugLevel:int=0)
        {
            super(table, sqlConnection, debugLevel);
        }

        public function setPk(column:String):void
        {
            _pk = column + " integer primary key autoincrement";
            _changed = true;
        }

        override public function addColumn(column:String, type:String):void
        {
            if (_columns == null)
                _columns = new Object();

            _columns[column] = { type: type, constraint: null };
            _changed = true;
        }

        public function addFkColumn(
            column:String,
            type:String,
            fkConstraintTable:String,
            fkConstraintColumn:String):void
        {
            if (_columns == null)
                _columns = new Object();

            _columns[column] = { type: type, constraint: { table: fkConstraintTable, column: fkConstraintColumn } };
            _changed = true;
        }

        override protected function prepareStatement():void
        {
            var sql:String = null;
            var existingColumns:ArrayCollection = getExistingColumns();
            if (existingColumns)
            {
                _created = true;
                sql = buildAlterSQL(existingColumns);
            }
            else
            {
                sql = buildCreateSQL();
            }
            if (sql)
                _statement.text = sql;

            _changed = false;
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
                    for each(var column:SQLColumnSchema in schemaResult.tables[0].columns)
                    {
                        if (!column.primaryKey)
                        {
                            existingColumns.addItem(column.name);
                        }
                    }
                    return existingColumns;
                }
            }
            catch (error:SQLError) { }
            return null;
        }

        private function buildAlterSQL(existingColumns:ArrayCollection):String
        {
            var sql:String = "";
            for (var column:String in _columns)
            {
                if (!existingColumns.contains(column))
                {
                    sql += "alter table " + _table +
                        " add " + column + " " + _columns[column].type + ";";
                }
            }
            return (sql == "")? null : sql;
        }

        private function buildCreateSQL():String
        {
            var sql:String = "create table if not exists " + _table + " (";
            if (_pk)
            {
                sql += _pk + ",";
            }
            for (var column:String in _columns)
            {
                sql += column + " " + _columns[column].type + ",";
            }
            sql = sql.substring(0, sql.length - 1) + ")"; // remove last comma
            return sql;
        }

        override public function execute():void
        {
            if (_changed)
                prepareStatement();

            if (!_statement.text) // if _statement.text == null || ""
                return;

            if (_debugLevel > 0)
                debug();

            _statement.execute();
            if (!_created)
            {
                // create foreign key constraint triggers
                for (var column:String in _columns)
                {
                    var constraint:Object = _columns[column].constraint;
                    if (constraint)
                    {
                        var insertTrigger:ICommand = new FkConstraintInsertTriggerCommand(_table, column, constraint.table, constraint.column, _sqlConnection, _debugLevel);
                        insertTrigger.execute();
                        var updateTrigger:ICommand = new FkConstraintUpdateTriggerCommand(_table, column, constraint.table, constraint.column, _sqlConnection, _debugLevel);
                        updateTrigger.execute();
                        var deleteTrigger:ICommand = new FkConstraintDeleteTriggerCommand(_table, column, constraint.table, constraint.column, _sqlConnection, _debugLevel);
                        deleteTrigger.execute();
                    }
                }
            }
        }

        public function toString():String
        {
            return "CREATE " + _table + ": " + _statement.text;
        }

    }
}