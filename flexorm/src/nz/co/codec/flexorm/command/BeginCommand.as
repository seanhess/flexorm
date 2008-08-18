package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;
    import flash.data.SQLTransactionLockType;
    import flash.errors.SQLError;
    import flash.events.SQLEvent;
    import flash.net.Responder;

    import mx.rpc.IResponder;

    import nz.co.codec.flexorm.EntityErrorEvent;
    import nz.co.codec.flexorm.EntityEvent;
    import nz.co.codec.flexorm.ICommand;

    public class BeginCommand implements ICommand
    {
        private var _sqlConnection:SQLConnection;

        private var _responder:IResponder;

        public function BeginCommand(sqlConnection:SQLConnection)
        {
            _sqlConnection = sqlConnection;
        }

        public function set responder(value:IResponder):void
        {
            _responder = value;
        }

        public function execute():void
        {
            _sqlConnection.begin(SQLTransactionLockType.DEFERRED, new Responder(

                function(ev:SQLEvent):void
                {
                    _responder.result(new EntityEvent(ev.type));
                },

                function(err:SQLError):void
                {
                    _responder.fault(new EntityErrorEvent(err.message, err));
                }
            ));
        }

    }
}