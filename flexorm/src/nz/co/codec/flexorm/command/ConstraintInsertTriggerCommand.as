package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;

    public class ConstraintInsertTriggerCommand extends SQLCommand
    {
        public function ConstraintInsertTriggerCommand(
            sqlConnection:SQLConnection,
            schema:String,
            table:String,
            column:String,
            constraintTable:String,
            constraintColumn:String,
            debugLevel:int=0)
        {
            super(sqlConnection, schema, table, debugLevel);
            _statement.text = "create trigger fki_" + table + "_" + column +
                " before insert on " + schema + "." + table +
                " for each row begin" +
                " select raise(rollback, 'insert on table \"" + table +
                "\" violates foreign key constraint \"fki_" + table + "_" + column + "\"')" +
                " where new." + column + " is not null and new." + column +
                " <> 0 and (select " + constraintColumn + " from " + schema + "." + constraintTable +
                " where " + constraintColumn + " = new." + column + ") is null; end;";
        }

        public function toString():String
        {
            return "CREATE FK CONSTRAINT INSERT TRIGGER " + _statement.text;
        }

    }
}