package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;

    public class ConstraintDeleteTriggerCommand extends SQLCommand
    {
        public function ConstraintDeleteTriggerCommand(
            sqlConnection:SQLConnection,
            schema:String,
            table:String,
            column:String,
            constraintTable:String,
            constraintColumn:String,
            debugLevel:int=0)
        {
            super(sqlConnection, schema, table, debugLevel);
            _statement.text = "create trigger fkd_" + table + "_" + column +
                " before delete on " + schema + "." + constraintTable +
                " for each row begin" +
                " select raise(rollback, 'delete on table \"" + constraintTable +
                "\" violates foreign key constraint \"fkd_" + table + "_" + column + "\"')" +
                " where (select " + column + " from " + schema + "." + table +
                " where " + column + " = old." + constraintColumn + ") is not null; end;";
        }

        public function toString():String
        {
            return "CREATE FK CONSTRAINT DELETE TRIGGER " + _statement.text;
        }

    }
}