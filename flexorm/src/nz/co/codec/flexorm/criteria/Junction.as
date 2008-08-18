package nz.co.codec.flexorm.criteria
{
    import nz.co.codec.flexorm.metamodel.Entity;

    public class Junction implements Restriction
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

        private var type:String;

        private var restrictions:Array;

        public function Junction(entity:Entity, type:String=null)
        {
            _entity = entity;
            switch (type)
            {
                case OR:
                    type = OR;
                    break;

                default:
                    type = AND;
            }
            restrictions = [];
        }

        public function addJunction(junction:Junction):Junction
        {
            restrictions.push(junction);
            return this;
        }

        public function addLikeCondition(property:String, str:String):Junction
        {
            var column:String = _entity.getColumn(property);
            if (column)
            {
                restrictions.push(new LikeCondition(column, str));
            }
            return this;
        }

        public function addNullCondition(property:String):Junction
        {
            var column:String = _entity.getColumn(property);
            if (column)
            {
                restrictions.push(new NullCondition(column));
            }
            return this;
        }

        public function addNotNullCondition(property:String):Junction
        {
            var column:String = _entity.getColumn(property);
            if (column)
            {
                restrictions.push(new NotNullCondition(column));
            }
            return this;
        }

        public function toString():String
        {
            var sql:String = "";
            var len:int = restrictions.length;
            if (len > 0)
            {
                sql += "(";
                var k:int = len - 1;
                for (var i:int = 0; i < len; i++)
                {
                    sql += restrictions[i];
                    if (i < k)
                        sql += type;
                }
                sql += ")";
            }
            return sql;
        }

    }
}