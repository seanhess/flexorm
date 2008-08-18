package nz.co.codec.flexorm.command
{
    import flash.data.SQLColumnSchema;
    import flash.data.SQLConnection;
    import flash.data.SQLSchemaResult;
    import flash.data.SQLTableSchema;
    import flash.errors.SQLError;

    import mx.collections.ArrayCollection;

    import nz.co.codec.flexorm.ICommand;

    public class CreateSyncCommand extends SQLCommand
    {
        private var _created:Boolean;

        private var _pk:String;

        public function CreateSyncCommand(
            sqlConnection:SQLConnection,
            schema:String,
            table:String,
            debugLevel:int=0)
        {
            super(sqlConnection, schema, table, debugLevel);
            _created = false;
        }

        public function setPrimaryKey(column:String):void
        {
            _pk = column + " integer primary key autoincrement";
            _changed = true;
        }

        override public function addColumn(column:String, type:String):void
        {
            _columns[column] = { type: type };
            _changed = true;
        }

        public function addForeignKey(
            column:String,
            type:String,
            constraintTable:String,
            constraintColumn:String):void
        {
            _columns[column] = {
                type: type,
                constraint: {
                    table: constraintTable,
                    column: constraintColumn
                }
            };
            _changed = true;
        }

        override protected function prepareStatement():void
        {
            var sql:String = null;
            var existingColumns:ArrayCollection = getExistingColumns();
            if (existingColumns)
            {
                sql = buildAlterSQL(existingColumns);
                _created = true;
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
            catch (err:SQLError) { }
            return null;
        }

        private function buildAlterSQL(existingColumns:ArrayCollection):String
        {
            var sql:String = "";
            for (var column:String in _columns)
            {
                if (!existingColumns.contains(column))
                {
                    sql += "alter table " + _schema + "." + _table +
                        " add " + column + " " + _columns[column].type + ";";
                }
            }
            return (sql.length > 0)? sql : null;
        }

        private function buildCreateSQL():String
        {
            var sql:String = "create table if not exists " + _schema + "." + _table + "(";
            if (_pk)
                sql += _pk + ",";

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

            // Create foreign key constraint triggers
            if (!_created)
            {
                for (var column:String in _columns)
                {
                    var constraint:Object = _columns[column].constraint;
                    if (constraint)
                    {
                        var insertTrigger:ICommand = new ConstraintInsertTriggerCommand(_sqlConnection, _schema, _table, column, constraint.table, constraint.column, _debugLevel);
                        insertTrigger.execute();

                        var updateTrigger:ICommand = new ConstraintUpdateTriggerCommand(_sqlConnection, _schema, _table, column, constraint.table, constraint.column, _debugLevel);
                        updateTrigger.execute();

                        var deleteTrigger:ICommand = new ConstraintDeleteTriggerCommand(_sqlConnection, _schema, _table, column, constraint.table, constraint.column, _debugLevel);
                        deleteTrigger.execute();
                    }
                }
            }
        }

        public function toString():String
        {
            return "CREATE SYNC " + _table + ": " + _statement.text;
        }

    }
}