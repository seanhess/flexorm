package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;

    public class FkConstraintDeleteTriggerCommand extends SQLCommand
    {
        public function FkConstraintDeleteTriggerCommand(
            table:String,
            column:String,
            fkConstraintTable:String,
            fkConstraintColumn:String,
            sqlConnection:SQLConnection,
            debugLevel:int=0)
        {
            super(table, sqlConnection, debugLevel);
            _statement.text = "create trigger fkd_" + _table + "_" + column +
                " before delete on " + fkConstraintTable +
                " for each row begin" +
                " select raise(rollback, 'delete on table \"" + fkConstraintTable +
                "\" violates foreign key constraint \"fkd_" + _table + "_" + column + "\"')" +
                " where (select " + column + " from " + _table +
                " where " + column + " = old." + fkConstraintColumn + ") is not null; end;";
        }

        public function toString():String
        {
            return "CREATE FK Constraint Delete Trigger: " + _statement.text;
        }

    }
}