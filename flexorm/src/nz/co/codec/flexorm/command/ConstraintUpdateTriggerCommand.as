package nz.co.codec.flexorm.command
{
    import flash.data.SQLConnection;

    import mx.utils.StringUtil;

    public class ConstraintUpdateTriggerCommand extends SQLCommand
    {
        public function ConstraintUpdateTriggerCommand(
            sqlConnection:SQLConnection,
            schema:String,
            table:String,
            column:String,
            constraintTable:String,
            constraintColumn:String,
            debugLevel:int=0)
        {
            super(sqlConnection, schema, table, debugLevel);
            _statement.text = StringUtil.substitute("create trigger fku_{1}_{2} before update on {0}.{1} for each row begin select raise(rollback, 'update on table \"{1}\" violates foreign key constraint \"fku_{1}_{2}\"') where new.{2} is not null and new.{2}<>0 and (select t.{4} from {0}.{3} t where {4}=new.{2}) is null; end;",
                schema, table, column, constraintTable, constraintColumn);
        }

        public function toString():String
        {
            return "CREATE FK CONSTRAINT UPDATE TRIGGER " + _statement.text;
        }

    }
}