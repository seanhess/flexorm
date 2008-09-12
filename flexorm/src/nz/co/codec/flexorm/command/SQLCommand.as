package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;
    import flash.data.SQLStatement;
    import flash.events.SQLErrorEvent;
    import flash.events.SQLEvent;
    import flash.utils.getQualifiedClassName;

    import mx.rpc.IResponder;

    import nz.co.codec.flexorm.EntityErrorEvent;
    import nz.co.codec.flexorm.EntityEvent;
    import nz.co.codec.flexorm.ICommand;
    import nz.co.codec.flexorm.criteria.EqualsCondition;
    import nz.co.codec.flexorm.criteria.IFilter;
    import nz.co.codec.flexorm.criteria.SQLCondition;

    public class SQLCommand implements ICommand
    {
        protected var _sqlConnection:SQLConnection;

        protected var _schema:String;

        protected var _table:String;

        protected var _debugLevel:int;

        protected var _statement:SQLStatement;

        protected var _changed:Boolean;

        protected var _columns:Object;

        protected var _filters:Array;

        protected var _responder:IResponder;

        protected var _responded:Boolean;

        public function SQLCommand(sqlConnection:SQLConnection, schema:String, table:String, debugLevel:int=0)
        {
            _sqlConnection = sqlConnection;
            _schema = schema;
            _table = table;
            _debugLevel = debugLevel;
            _statement = new SQLStatement();
            _statement.sqlConnection = sqlConnection;
            _changed = true;
            _responded = false;
            _columns = {};
            _filters = [];
        }

        public function set responder(value:IResponder):void
        {
            _responder = value;
            _statement.addEventListener(SQLEvent.RESULT, resultHandler);
            _statement.addEventListener(SQLErrorEvent.ERROR, errorHandler);
        }

        protected function resultHandler(event:SQLEvent):void
        {
            respond(event);
            _responded = true;
        }

        protected function respond(event:SQLEvent):void
        {
            _responder.result(new EntityEvent(event.type));
        }

        public function get responded():Boolean
        {
            return _responded;
        }

        protected function errorHandler(event:SQLErrorEvent):void
        {
            trace(event.error.details);
            _responder.fault(new EntityErrorEvent(event.error.details, event.error));
        }

        public function set columns(value:Object):void
        {
            _columns = value;
            _changed = true;
        }

        public function addColumn(column:String, param:String=null, table:String=null):void
        {
            if (param == null)
            {
                _columns[column] = ":" + column;
            }
            else
            {
                if (param.indexOf(":") == 0)
                {
                    _columns[column] = param;
                }
                else
                {
                    _columns[column] = ":" + param;
                }
            }
            _changed = true;
        }

        public function get columns():Object
        {
            return _columns;
        }

        public function addFilter(column:String, param:String, table:String=null):void
        {
            if (table == null)
            {
                if (_table == null)
                {
                    throw new Error("Unknown table: " + getQualifiedClassName(this));
                }
                else
                {
                    table = _table;
                }
            }
            addEqualsCondition(table, column, param);
        }

        public function addFilterObject(filter:IFilter):void
        {
            _filters.push(filter);
        }

        public function addEqualsCondition(table:String, column:String, param:String):void
        {
            if (table && column && param)
            {
                _filters.push(new EqualsCondition(table, column, param));
            }
            else
            {
                throw new Error("Null argument supplied to "
                    + getQualifiedClassName(this) + ".addEqualsCondition ");
            }
            _changed = true;
        }

        public function addSQLCondition(sql:String):void
        {
            if (sql)
            {
                _filters.push(new SQLCondition(_table, sql));
            }
            else
            {
                throw new Error("Null argument supplied to "
                    + getQualifiedClassName(this) + ".addSQLCondition ");
            }
            _changed = true;
        }

        public function get filters():Array
        {
            return _filters;
        }

        // abstract
        protected function prepareStatement():void { }

        public function execute():void
        {
            if (_changed)
                prepareStatement();

            if (_debugLevel > 0)
                debug();

            _statement.execute();
        }

        protected function set debugLevel(value:int):void
        {
            _debugLevel = value;
        }

        protected function debug():void
        {
            trace(this);
        }

    }
}