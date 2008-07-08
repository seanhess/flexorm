package nz.co.codec.flexorm
{
    import flash.data.SQLConnection;

    import nz.co.codec.flexorm.command.SQLParameterisedCommand;
    import nz.co.codec.flexorm.metamodel.Entity;

    public class Criteria extends SQLParameterisedCommand
    {
        private var _entity:Entity;

        public function Criteria(entity:Entity, sqlConnection:SQLConnection, debugLevel:int)
        {
            super(entity.table, sqlConnection, debugLevel);
            _entity = entity;
        }

        override protected function prepareStatement():void
        {
            var sql:String = "select * from " + _table;
        }

        public function addLike():void
        {

        }

    }
}