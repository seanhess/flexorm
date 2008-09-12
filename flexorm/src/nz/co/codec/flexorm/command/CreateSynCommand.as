package nz.co.codec.flexorm.command
{
    import flash.data.SQLColumnSchema;
    import flash.data.SQLConnection;
    import flash.data.SQLSchemaResult;
    import flash.data.SQLTableSchema;
    import flash.errors.SQLError;

    import mx.collections.ArrayCollection;
    import mx.utils.StringUtil;

    import nz.co.codec.flexorm.metamodel.IDStrategy;

    public class CreateSynCommand extends SQLCommand
    {
        private var _created:Boolean;

        private var _pk:String;

        private var _idColumn:String;

        public function CreateSynCommand(
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
            _idColumn = column;
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
            catch (e:SQLError) { }
            return null;
        }

        private function buildAlterSQL(existingColumns:ArrayCollection):String
        {
            var sql:String = "";
            for (var column:String in _columns)
            {
                if (!existingColumns.contains(column) && column != _idColumn)
                {
                    sql += StringUtil.substitute("alter table {0}.{1} add {2} {3};",
                           _schema, _table, column, _columns[column].type);
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
                        new ConstraintInsertTriggerCommand(_sqlConnection, _schema, _table, column, constraint.table, constraint.column, _debugLevel).execute();
                        new ConstraintUpdateTriggerCommand(_sqlConnection, _schema, _table, column, constraint.table, constraint.column, _debugLevel).execute();
                        new ConstraintDeleteTriggerCommand(_sqlConnection, _schema, _table, column, constraint.table, constraint.column, _debugLevel).execute();
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