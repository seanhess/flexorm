package nz.co.codec.flexorm.command
{
    import flash.data.SQLColumnSchema;
    import flash.data.SQLConnection;
    import flash.data.SQLSchemaResult;
    import flash.data.SQLTableSchema;
    import flash.events.SQLErrorEvent;
    import flash.events.SQLEvent;

    import mx.collections.ArrayCollection;
    import mx.utils.StringUtil;

    import nz.co.codec.flexorm.BlockingExecutor;
    import nz.co.codec.flexorm.EntityEvent;
    import nz.co.codec.flexorm.metamodel.IDStrategy;

    public class CreateAsynCommand extends SQLCommand
    {
        private var _created:Boolean;

        private var _pk:String;

        public function CreateAsynCommand(
            sqlConnection:SQLConnection,
            schema:String,
            table:String,
            debugLevel:int=0)
        {
            super(sqlConnection, schema, table, debugLevel);
            _created = false;
        }

        public function setPrimaryKey(column:String, idStrategy:String):void
        {
            if (IDStrategy.UID == idStrategy)
            {
                _pk = StringUtil.substitute("{0} string primary key", column);
            }
            else
            {
                _pk = StringUtil.substitute("{0} integer primary key autoincrement", column);
            }
            _changed = true;
        }

        override public function addColumn(column:String, type:String=null, table:String=null):void
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
                type      : type,
                constraint: {
                    table : constraintTable,
                    column: constraintColumn
                }
            };
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
                q.responder = _responder;
                q.data = event.type;

                // Create foreign key constraint triggers
                for (var column:String in _columns)
                {
                    var constraint:Object = _columns[column].constraint;
                    if (constraint)
                    {
                        q.add(new ConstraintInsertTriggerCommand(_sqlConnection, _schema, _table, column, constraint.table, constraint.column, _debugLevel));
                        q.add(new ConstraintUpdateTriggerCommand(_sqlConnection, _schema, _table, column, constraint.table, constraint.column, _debugLevel));
                        q.add(new ConstraintDeleteTriggerCommand(_sqlConnection, _schema, _table, column, constraint.table, constraint.column, _debugLevel));
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
            // should have the one table requested or the errorHandler is called
            for each(var column:SQLColumnSchema in schemaResult.tables[0].columns)
            {
                if (!column.primaryKey)
                {
                    existingColumns.addItem(column.name);
                }
            }
            return existingColumns;
        }

        private function buildAlterSQL(existingColumns:ArrayCollection):String
        {
            var sql:String = "";
            for (var column:String in _columns)
            {
                if (!existingColumns.contains(column))
                {
                    sql += StringUtil.substitute("alter table {0} add {1} {2};",
                            _table, column, _columns[column].type);
                }
            }
            return (sql.length > 0)? sql : null;
        }

        private function buildCreateSQL():String
        {
            var sql:String = StringUtil.substitute("create table if not exists {0}.{1}(", _schema, _table);
            if (_pk)
                sql += _pk + ",";

            for (var column:String in _columns)
            {
                sql += StringUtil.substitute("{0} {1},", column, _columns[column].type);
            }
            sql = sql.substring(0, sql.length - 1) + ")"; // remove last comma
            return sql;
        }

        public function toString():String
        {
            return "CREATE " + _table + ": " + _statement.text;
        }

    }
}