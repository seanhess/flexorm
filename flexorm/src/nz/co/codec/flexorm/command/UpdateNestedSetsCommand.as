package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;

    import mx.utils.StringUtil;

    public class UpdateNestedSetsCommand extends SQLParameterisedCommand
    {
        public function UpdateNestedSetsCommand(sqlConnection:SQLConnection, schema:String, table:String, debugLevel:int=0)
        {
            super(sqlConnection, schema, table, debugLevel);
            _statement.text = StringUtil.substitute("update {0}.{1} set lft=lft+:inc,rgt=rgt+:inc where lft>:lft and rgt<:rgt", schema, table);
        }

        public function toString():String
        {
            return "UPDATE NESTED SETS " + _table + ": " + _statement.text;
        }

    }
}