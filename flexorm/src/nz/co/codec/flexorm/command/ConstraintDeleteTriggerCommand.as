package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;

    import mx.utils.StringUtil;

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
            _statement.text = StringUtil.substitute("create trigger fkd_{1}_{2} before delete on {0}.{3} for each row begin select raise(rollback, 'delete on table \"{3}\" violates foreign key constraint \"fkd_{1}_{2}\"') where (select t.{2} from {0}.{1} t where t.{2}=old.{4}) is not null; end;",
                schema, table, column, constraintTable, constraintColumn);
        }

        public function toString():String
        {
            return "CREATE FK CONSTRAINT DELETE TRIGGER: " + _statement.text;
        }

    }
}