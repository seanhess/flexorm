package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;
    import flash.data.SQLTransactionLockType;
    import flash.errors.SQLError;
    import flash.events.SQLEvent;
    import flash.net.Responder;

    import mx.rpc.IResponder;

    import nz.co.codec.flexorm.EntityError;
    import nz.co.codec.flexorm.EntityEvent;
    import nz.co.codec.flexorm.ICommand;

    public class BeginCommand implements ICommand
    {
        protected var _sqlConnection:SQLConnection;

        private var _responder:IResponder;

        public function BeginCommand(sqlConnection:SQLConnection)
        {
            _sqlConnection = sqlConnection;
        }

        public function setResponder(value:IResponder):void
        {
            _responder = value;
        }

        public function execute():void
        {
            _sqlConnection.begin(SQLTransactionLockType.DEFERRED, new Responder(
                function(event:SQLEvent):void
                {
                    _responder.result(new EntityEvent(event.type));
                },

                function(error:SQLError):void
                {
                    _responder.fault(new EntityError(error.message, error));
                }
            ));
        }

    }
}