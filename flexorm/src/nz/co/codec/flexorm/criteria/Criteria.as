package nz.co.codec.flexorm.criteria
{
    import flash.data.SQLConnection;

    import nz.co.codec.flexorm.command.SQLParameterisedCommand;
    import nz.co.codec.flexorm.metamodel.Entity;

    public class Criteria extends SQLParameterisedCommand
    {
        private var _entity:Entity;

        private var _result:Array;

        private var restrictions:Array;

        private var sorts:Array;

        public function Criteria(
            sqlConnection:SQLConnection,
            schema:String,
            entity:Entity,
            debugLevel:int=0)
        {
            super(sqlConnection, schema, entity.table, debugLevel);
            _entity = entity;
            restrictions = [];
            sorts = [];
        }

        public function get entity():Entity
        {
            return _entity;
        }

        override protected function prepareStatement():void
        {
            var sql:String = "select ";
            for (var column:String in _columns)
            {
                sql += "t." + column + ",";
            }
            sql = sql.substring(0, sql.length - 1); // remove last comma
            sql += " from " + _schema + "." + _entity.table + " t";
            sql += " where ";
            for each(var restriction:Restriction in restrictions)
            {
                sql += restriction + " and ";
            }
            sql += "t.marked_for_deletion<>true";
            if (sorts.length > 0)
            {
                sql += " order by ";
                for each(var sort:Sort in sorts)
                {
                    sql += sort + " and ";
                }
                sql = sql.substring(0, sql.length - 5); // remove last ' and '
            }

            _statement.text = sql;
            _changed = false;
        }

        override public function execute():void
        {
            super.execute();
            if (_responder == null)
                _result = _statement.getResult().data;
        }

        public function get result():Array
        {
            return _result;
        }

        public function addSort(property:String, order:String):Criteria
        {
            var column:String = _entity.getColumn(property);
            if (column)
            {
                sorts.push(new Sort(column, order));
            }
            _changed = true;
            return this;
        }

        public function addJunction(junction:Junction):Criteria
        {
            restrictions.push(junction);
            _changed = true;
            return this;
        }

        public function addLikeCondition(property:String, str:String):Criteria
        {
            var column:String = _entity.getColumn(property);
            if (column)
            {
                restrictions.push(new LikeCondition(column, str));
            }
            _changed = true;
            return this;
        }

        public function addNullCondition(property:String):Criteria
        {
            var column:String = _entity.getColumn(property);
            if (column)
            {
                restrictions.push(new NullCondition(column));
            }
            _changed = true;
            return this;
        }

        public function addNotNullCondition(property:String):Criteria
        {
            var column:String = _entity.getColumn(property);
            if (column)
            {
                restrictions.push(new NotNullCondition(column));
            }
            _changed = true;
            return this;
        }

        public function toString():String
        {
            return "SELECT BY CRITERIA " + _table + ": " + _statement.text;
        }

    }
}