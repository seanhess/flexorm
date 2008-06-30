package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;

    public class FkConstraintUpdateTriggerCommand extends SQLCommand
    {
        public function FkConstraintUpdateTriggerCommand(
            table:String,
            column:String,
            fkConstraintTable:String,
            fkConstraintColumn:String,
            sqlConnection:SQLConnection,
            debugLevel:int=0)
        {
            super(table, sqlConnection, debugLevel);
            _statement.text = "create trigger fku_" + _table + "_" + column +
                " before update on " + _table +
                " for each row begin" +
                " select raise(rollback, 'update on table \"" + _table +
                "\" violates foreign key constraint \"fku_" + _table + "_" + column + "\"')" +
                " where new." + column + " is not null and new." + column +
                " <> 0 and (select " + fkConstraintColumn + " from " + fkConstraintTable +
                " where " + fkConstraintColumn + " = new." + column + ") is null; end;";
        }

        public function toString():String
        {
            return "CREATE FK Constraint Update Trigger: " + _statement.text;
        }

    }
}