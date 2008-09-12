package nz.co.codec.flexorm.criteria
{
    import nz.co.codec.flexorm.metamodel.Entity;

    public class Criteria
    {
        private var _entity:Entity;

        private var _filters:Array;

        private var _sorts:Array;

        private var _params:Object;

        public function Criteria(entity:Entity)
        {
            _entity = entity;
            _filters = [];
            _sorts = [];
            _params = {};
        }

        public function get entity():Entity
        {
            return _entity;
        }

        public function get filters():Array
        {
            return _filters;
        }

        public function get sorts():Array
        {
            return _sorts;
        }

        public function get params():Object
        {
            return _params;
        }

        public function addSort(property:String, order:String=null):Criteria
        {
            var column:Object = _entity.getColumn(property);
            if (column)
            {
                _sorts.push(new Sort(column.table, column.column, order));
            }
            return this;
        }

        public function createAndJunction():Junction
        {
            return Junction.and(_entity);
        }

        public function createOrJunction():Junction
        {
            return Junction.or(_entity);
        }

        public function addJunction(junction:Junction):Criteria
        {
            _filters.push(junction);
            return this;
        }

        public function addEqualsCondition(property:String, value:Object):Criteria
        {
            var column:Object = _entity.getColumn(property);
            if (column)
            {
                _filters.push(new EqualsCondition(column.table, column.column, property));
                _params[property] = value;
            }
            return this;
        }

        public function addNotEqualsCondition(property:String, value:Object):Criteria
        {
            var column:Object = _entity.getColumn(property);
            if (column)
            {
                _filters.push(new NotEqualsCondition(column.table, column.column, property));
                _params[property] = value;
            }
            return this;
        }

        public function addGreaterThanCondition(property:String, str:String):Criteria
        {
            var column:Object = _entity.getColumn(property);
            if (column)
            {
                _filters.push(new GreaterThanCondition(column.table, column.column, str));
            }
            return this;
        }

        public function addLessThanCondition(property:String, str:String):Criteria
        {
            var column:Object = _entity.getColumn(property);
            if (column)
            {
                _filters.push(new LessThanCondition(column.table, column.column, str));
            }
            return this;
        }

        public function addLikeCondition(property:String, str:String):Criteria
        {
            var column:Object = _entity.getColumn(property);
            if (column)
            {
                _filters.push(new LikeCondition(column.table, column.column, str));
            }
            return this;
        }

        public function addNullCondition(property:String):Criteria
        {
            var column:Object = _entity.getColumn(property);
            if (column)
            {
                _filters.push(new NullCondition(column.table, column.column));
            }
            return this;
        }

        public function addNotNullCondition(property:String):Criteria
        {
            var column:Object = _entity.getColumn(property);
            if (column)
            {
                _filters.push(new NotNullCondition(column.table, column.column));
            }
            return this;
        }

    }
}