package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;

    import mx.utils.StringUtil;

    public class UpdateNestedSetsRightBoundaryCommand extends SQLParameterisedCommand
    {
        public function UpdateNestedSetsRightBoundaryCommand(sqlConnection:SQLConnection, schema:String, table:String, debugLevel:int=0)
        {
            super(sqlConnection, schema, table, debugLevel);
            _statement.text = StringUtil.substitute("update {0}.{1} set rgt=rgt+:inc where rgt>=:rgt", schema, table);
        }

        public function toString():String
        {
            return "UPDATE NESTED SETS RIGHT BOUNDARY " + _table + ": " + _statement.text;
        }

    }
}