package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;
    import flash.data.SQLStatement;
    import flash.events.SQLErrorEvent;
    import flash.events.SQLEvent;

    import mx.rpc.IResponder;

    import nz.co.codec.flexorm.EntityError;
    import nz.co.codec.flexorm.EntityEvent;
    import nz.co.codec.flexorm.ICommand;

    public class SQLCommand implements ICommand
    {
        protected var _table:String;

        protected var _sqlConnection:SQLConnection;

        protected var _debugLevel:int;

        protected var _statement:SQLStatement;

        protected var _changed:Boolean;

        protected var _columns:Object;

        protected var _filters:Object;

        protected var _responder:IResponder;

        protected var _responded:Boolean;

        public function SQLCommand(table:String, sqlConnection:SQLConnection, debugLevel:int=0)
        {
            _table = table;
            _sqlConnection = sqlConnection;
            _debugLevel = debugLevel;
            _statement = new SQLStatement();
            _statement.sqlConnection = sqlConnection;
            _changed = true;
            _responded = false;
        }

        // TODO remove; for debugging purposes
        public function get statement():SQLStatement
        {
            return _statement;
        }

        protected function set columns(value:Object):void
        {
            _columns = value;
        }

        protected function set filters(value:Object):void
        {
            _filters = value;
        }

        protected function set debugLevel(value:int):void
        {
            _debugLevel = value;
        }

        public function addColumn(column:String, param:String):void
        {
            if (_columns == null)
                _columns = new Object();

            _columns[column] = ":" + param;
            _changed = true;
        }

        public function addFilter(column:String, param:String):void
        {
            if (_filters == null)
                _filters = new Object();

            _filters[column] = ":" + param;
            _changed = true;
        }

        public function setResponder(value:IResponder):void
        {
            _responder = value;
            _statement.addEventListener(SQLEvent.RESULT, resultHandler);
            _statement.addEventListener(SQLErrorEvent.ERROR, errorHandler);
        }

        protected function resultHandler(event:SQLEvent):void
        {
            _statement.removeEventListener(SQLEvent.RESULT, resultHandler);
            _statement.removeEventListener(SQLErrorEvent.ERROR, errorHandler);
            respond(event);
            _responded = true;
        }

        protected function errorHandler(event:SQLErrorEvent):void
        {
            _statement.removeEventListener(SQLEvent.RESULT, resultHandler);
            _statement.removeEventListener(SQLErrorEvent.ERROR, errorHandler);
            _responder.fault(new EntityError(event.error.message, event.error));
        }

        protected function respond(event:SQLEvent):void
        {
            _responder.result(new EntityEvent(event.type));
        }

        public function get responded():Boolean
        {
            return _responded;
        }

        // abstract
        protected function prepareStatement():void { }

        public function execute():void
        {
            if (_changed)
            {
                prepareStatement();
            }
            if (_debugLevel > 0)
            {
                debug();
            }
            _statement.execute();
        }

        protected function debug():void
        {
            trace(this);
        }

    }
}