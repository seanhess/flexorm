package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;
    import flash.events.SQLEvent;
    import flash.utils.getQualifiedClassName;

    import mx.utils.StringUtil;

    import nz.co.codec.flexorm.criteria.Criteria;
    import nz.co.codec.flexorm.criteria.ICondition;
    import nz.co.codec.flexorm.criteria.IFilter;
    import nz.co.codec.flexorm.criteria.Junction;
    import nz.co.codec.flexorm.criteria.Sort;

    public class SelectCommand extends SQLParameterisedCommand
    {
        private var _joins:Object;

        private var _sorts:Array;

        private var _result:Array;

        public function SelectCommand(sqlConnection:SQLConnection, schema:String, table:String=null, debugLevel:int=0)
        {
            super(sqlConnection, schema, table, debugLevel);
            _joins = {};
            _sorts = [];
        }

        public function clone():SelectCommand
        {
            var copy:SelectCommand = new SelectCommand(_sqlConnection, _schema, _table, _debugLevel);
            copy.mergeColumns(_columns);
            copy.mergeJoins(_joins);
            copy._filters = _filters.concat();
            copy._sorts = _sorts.concat();
            return copy;
        }

        public function mergeColumns(source:Object):void
        {
            for (var table:String in source)
            {
                for (var column:String in source[table])
                {
                    addColumn(column, source[table][column], table);
                }
            }
        }

        override public function addColumn(column:String, param:String=null, table:String=null):void
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
            if (_columns[table] == null)
            {
                _columns[table] = {};
            }
            if (param == null)
            {
                _columns[table][column] = ":" + column;
            }
            else
            {
                if (param.indexOf(":") == 0)
                {
                    _columns[table][column] = param;
                }
                else
                {
                    _columns[table][column] = ":" + param;
                }
            }
            _changed = true;
        }

        public function setCriteria(crit:Criteria):void
        {
            _filters = crit.filters;
            _sorts = crit.sorts;

            var params:Object = crit.params;
            for (var param:String in params)
            {
                setParam(param, params[param]);
            }
            _changed = true;
        }

        public function set joins(value:Object):void
        {
            _joins = value;
            _changed = true;
        }

        public function mergeJoins(source:Object):void
        {
            for (var table:String in source)
            {
                for (var fk:String in source[table])
                {
                    addJoin(table, source[table][fk], fk);
                }
            }
        }

        public function mergeFilters(source:Array):void
        {
            _filters = _filters.concat(source);
        }

        public function mergeSorts(source:Array):void
        {
            _sorts = _sorts.concat(source);
        }

        public function addJoin(table:String, pk:String, fk:String):void
        {
            if (_joins[table] == null)
            {
                _joins[table] = {};
            }
            _joins[table][fk] = pk;
            _changed = true;
        }

        public function addSort(column:String, order:String=null, table:String=null):void
        {
            if (column)
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
                _sorts.push(new Sort(table, column, order? order : Sort.ASC));
                _changed = true;
            }
        }

        public function get sorts():Array
        {
            return _sorts;
        }

        override protected function prepareStatement():void
        {
            var sql:String = "select ";
            var tables:Array = [];
            var i:int = 0;
            var columnsAdded:Boolean = false;
            for (var table:String in _columns)
            {
                tables.push(table);
                for (var column:String in _columns[table])
                {
                    sql += StringUtil.substitute("t{0}.{1},", i, column);
                }
                i++;
                columnsAdded = true;
            }
            if (columnsAdded)
            {
                sql = sql.substring(0, sql.length-1); // remove last comma
            }
            else
            {
                sql += "*";
                tables.push(_table);
            }
            sql += " from ";
            for (var tabl:String in _joins)
            {
                if (tables.indexOf(tabl) == -1)
                    tables.push(tabl);
            }
            var len:int = tables.length;
            for (i = 0; i < len; i++)
            {
                sql += StringUtil.substitute("{0}.{1} t{2}", _schema, tables[i], i);
                if (i > 0)
                {
                    for (var fk:String in _joins[tables[i]])
                    {
                        sql += StringUtil.substitute(" on t{0}.{1}=t{2}.{3} and ", i-1, _joins[tables[i]][fk], i, fk);
                    }
                }
                if (i < len-1)
                {
                    sql += " inner join ";
                }
            }
            if (len > 1)
                sql = sql.substring(0, sql.length-5); // remove last ' and '
            if (_filters.length > 0)
            {
                sql += " where ";
                for each(var filter:IFilter in _filters)
                {
                    if (filter is Junction)
                    {
                        sql += StringUtil.substitute("{0} and ",
                                Junction(filter).getString(function(table:String):int
                                {
                                    return tables.indexOf(table);
                                }));
                    }
                    else
                    {
                        sql += StringUtil.substitute("t{0}.{1} and ",
                                tables.indexOf(ICondition(filter).table), filter);
                    }
                }
                sql = sql.substring(0, sql.length-5); // remove last ' and '
            }
            if (_sorts.length > 0)
            {
                sql += " order by ";
                for each(var sort:Sort in _sorts)
                {
                    sql += StringUtil.substitute("t{0}.{1} and ",
                            tables.indexOf(ICondition(sort).table), sort);
                }
                sql = sql.substring(0, sql.length-5); // remove last ' and '
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

        override protected function respond(event:SQLEvent):void
        {
            _result = _statement.getResult().data;
            _responder.result(_result);
        }

        public function get result():Array
        {
            return _result;
        }

        public function toString():String
        {
            return "SELECT " + _statement.text;
        }

    }
}