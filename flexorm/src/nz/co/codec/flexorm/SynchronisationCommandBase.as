package nz.co.codec.flexorm
{
    import flash.data.SQLConnection;
    import flash.data.SQLStatement;

    import mx.rpc.IResponder;

    import nz.co.codec.flexorm.metamodel.Entity;

    public class SynchronisationCommandBase implements ICommand
    {
        protected var _entity:Entity;

        protected var _syncMap:Object;

        protected var _url:String;

        protected var _sqlConnection:SQLConnection;

        protected var _credentials:Object;

        protected var _responder:IResponder;

        public function SynchronisationCommandBase(
            entity:Entity,
            syncMap:Object,
            url:String,
            sqlConnection:SQLConnection,
            credentials:Object)
        {
            _entity = entity;
            _syncMap = syncMap;
            _url = url;
            _sqlConnection = sqlConnection;
            _credentials = credentials;
        }

        public function setResponder(value:IResponder):void
        {
            _responder = value;
        }

        // abstract
        public function execute():void { }

        protected function getBaseUrl(url:String):String
        {
            if (url.match(/\/$/))
            {
                return url;
            }
            else
            {
                return url + "/";
            }
        }

        protected function getLastSyncDate(cn:String):Date
        {
            if (cn == null)
                return null;

            var statement:SQLStatement = new SQLStatement();
            statement.sqlConnection = _sqlConnection;
            statement.text = "select a.last_synchronised_at from main.app_data a where a.entity=:entity";
            statement.parameters[":entity"] = cn;
            statement.execute();
            var data:Array = statement.getResult().data;
            return data? data[0].last_synchronised_at : new Date(0);
        }

        protected function updateAppData(lastSyncDate:Date, cn:String):void
        {
            var statement:SQLStatement = new SQLStatement();
            statement.sqlConnection = _sqlConnection;
            if (lastSyncDate.time == 0)
            {
                statement.text = "insert into main.app_data(entity,last_synchronised_at) values(:entity,:lastSyncDate)";
            }
            else
            {
                statement.text = "update main.app_data set last_synchronised_at=:lastSyncDate where entity=:entity";
            }
            statement.parameters[":entity"] = cn;
            statement.parameters[":lastSyncDate"] = new Date();
            statement.execute();
        }

    }
}