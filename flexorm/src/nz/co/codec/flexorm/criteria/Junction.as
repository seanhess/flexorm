package nz.co.codec.flexorm.criteria
{
    import mx.utils.StringUtil;

    import nz.co.codec.flexorm.metamodel.Entity;

    public class Junction implements IFilter
    {
        public static const AND:String = " and ";

        public static const OR :String = " or ";

        public static function and(entity:Entity):Junction
        {
            return new Junction(entity, AND);
        }

        public static function or(entity:Entity):Junction
        {
            return new Junction(entity, OR);
        }

        private var _entity:Entity;

        private var _type:String;

        private var _filters:Array;

        public function Junction(entity:Entity, type:String=null)
        {
            _entity = entity;
            switch (type)
            {
                case OR:
                    _type = OR;
                    break;

                default:
                    _type = AND;
            }
            _filters = [];
        }

        public function addJunction(junction:Junction):Junction
        {
            _filters.push(junction);
            return this;
        }

        public function addLikeCondition(property:String, str:String):Junction
        {
            var column:Object = _entity.getColumn(property);
            if (column)
            {
                _filters.push(new LikeCondition(column.table, column.column, str));
            }
            return this;
        }

        public function addNullCondition(property:String):Junction
        {
            var column:Object = _entity.getColumn(property);
            if (column)
            {
                _filters.push(new NullCondition(column.table, column.column));
            }
            return this;
        }

        public function addNotNullCondition(property:String):Junction
        {
            var column:Object = _entity.getColumn(property);
            if (column)
            {
                _filters.push(new NotNullCondition(column.table, column.column));
            }
            return this;
        }

        public function get filters():Array
        {
            return _filters;
        }

        public function getString(getTableIndex:Function):String
        {
            var sql:String = "";
            var len:int = _filters.length;
            if (len > 0)
            {
                sql += "(";
                var k:int = len - 1;
                for (var i:int = 0; i < len; i++)
                {
                    sql += StringUtil.substitute("t{0}.{1}",
                            getTableIndex.call(this, Condition(_filters[i]).table),
                            _filters[i]);
                    if (i < k)
                        sql += _type;
                }
                sql += ")";
            }
            return sql;
        }

    }
}