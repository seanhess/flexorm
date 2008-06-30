package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;

    public class FkConstraintInsertTriggerCommand extends SQLCommand
    {
        public function FkConstraintInsertTriggerCommand(
            table:String,
            column:String,
            fkConstraintTable:String,
            fkConstraintColumn:String,
            sqlConnection:SQLConnection,
            debugLevel:int=0)
        {
            super(table, sqlConnection, debugLevel);
            _statement.text = "create trigger fki_" + _table + "_" + column +
                " before insert on " + _table +
                " for each row begin" +
                " select raise(rollback, 'insert on table \"" + _table +
                "\" violates foreign key constraint \"fki_" + _table + "_" + column + "\"')" +
                " where new." + column + " is not null and new." + column +
                " <> 0 and (select " + fkConstraintColumn + " from " + fkConstraintTable +
                " where " + fkConstraintColumn + " = new." + column + ") is null; end;";
        }

        public function toString():String
        {
            return "CREATE FK Constraint Insert Trigger: " + _statement.text;
        }

    }
}