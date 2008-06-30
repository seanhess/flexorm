package nz.co.codec.flexorm.command
{
    import flash.data.SQLColumnSchema;
    import flash.data.SQLConnection;
    import flash.data.SQLSchemaResult;
    import flash.data.SQLTableSchema;
    import flash.events.SQLErrorEvent;
    import flash.events.SQLEvent;

    import mx.collections.ArrayCollection;

    import nz.co.codec.flexorm.BlockingExecutor;
    import nz.co.codec.flexorm.EntityEvent;

    public class CreateCommandAsync extends SQLCommand
    {
        private var _pk:String;

        private var _created:Boolean = false;

        public function CreateCommandAsync(table:String, sqlConnection:SQLConnection, debugLevel:int=0)
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

        override public function execute():void
        {
            if (_changed)
            {
                _sqlConnection.addEventListener(SQLEvent.SCHEMA, loadSchemaResultHandler);
                _sqlConnection.addEventListener(SQLErrorEvent.ERROR, loadSchemaErrorHandler);
                _sqlConnection.loadSchema(SQLTableSchema, _table);
            }
            else
            {
                if (_debugLevel > 0)
                    debug();

                _statement.execute();
            }
        }

        private function loadSchemaResultHandler(event:SQLEvent):void
        {
            _sqlConnection.removeEventListener(SQLEvent.SCHEMA, loadSchemaResultHandler);
            _sqlConnection.removeEventListener(SQLErrorEvent.ERROR, loadSchemaErrorHandler);
            _changed = false;
            var existingColumns:ArrayCollection = getExistingColumns(_sqlConnection.getSchemaResult());
            if (existingColumns.length > 0)
            {
                _created = true;
                var sql:String = buildAlterSQL(existingColumns);
                if (sql)
                {
                    _statement.text = sql;
                    if (_debugLevel > 0)
                        debug();

                    _statement.execute();
                }
                else
                // no new columns defined
                {
                    respondUnaltered();
                }
            }
            else
            // I can think of only one reason: where the entity only has
            // an ID property.
            {
                respondUnaltered();
            }
        }

        private function respondUnaltered():void
        {
            _statement.removeEventListener(SQLEvent.RESULT, resultHandler);
            _statement.removeEventListener(SQLErrorEvent.ERROR, errorHandler);
            _responder.result(new EntityEvent("unaltered"));
            _responded = true;
        }

        private function loadSchemaErrorHandler(event:SQLErrorEvent):void
        {
            _sqlConnection.removeEventListener(SQLEvent.SCHEMA, loadSchemaResultHandler);
            _sqlConnection.removeEventListener(SQLErrorEvent.ERROR, loadSchemaErrorHandler);
            _statement.text = buildCreateSQL();
            _changed = false;
            if (_debugLevel > 0)
                debug();

            _statement.execute();
        }

        override protected function respond(event:SQLEvent):void
        {
            if (!_created)
            {
                var q:BlockingExecutor = new BlockingExecutor();
                q.response = event.type;
                q.setResponder(_responder);

                // create foreign key constraint triggers
                for (var column:String in _columns)
                {
                    var constraint:Object = _columns[column].constraint;
                    if (constraint)
                    {
                        q.addCommand(new FkConstraintInsertTriggerCommand(_table, column, constraint.table, constraint.column, _sqlConnection, _debugLevel));
                        q.addCommand(new FkConstraintUpdateTriggerCommand(_table, column, constraint.table, constraint.column, _sqlConnection, _debugLevel));
                        q.addCommand(new FkConstraintDeleteTriggerCommand(_table, column, constraint.table, constraint.column, _sqlConnection, _debugLevel));
                    }
                }
                q.execute();
            }
            else
            {
                _responder.result(new EntityEvent(event.type));
            }
        }

        private function getExistingColumns(schemaResult:SQLSchemaResult):ArrayCollection
        {
            var existingColumns:ArrayCollection = new ArrayCollection();
//			if (schemaResult.tables.length > 0)
//			{
//			should have the one table requested or the errorHandler is called
                for each(var column:SQLColumnSchema in schemaResult.tables[0].columns)
                {
                    if (!column.primaryKey)
                    {
                        existingColumns.addItem(column.name);
                    }
                }
//			}
            return existingColumns;
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
            // remove last comma
            sql = sql.substring(0, sql.length - 1) + ")";
            return sql;
        }

        public function toString():String
        {
            return "CREATE " + _table + ": " + _statement.text;
        }

    }
}