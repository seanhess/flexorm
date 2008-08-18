package nz.co.codec.flexorm.metamodel
{
    import nz.co.codec.flexorm.command.CreateSyncCommand;
    import nz.co.codec.flexorm.command.CreateAsynCommand;
    import nz.co.codec.flexorm.command.InsertCommand;
    import nz.co.codec.flexorm.command.SelectManyToManyCommand;
    import nz.co.codec.flexorm.command.SelectManyToManyKeysCommand;
    import nz.co.codec.flexorm.command.UpdateCommand;

    public class ManyToManyAssociation extends ListAssociation
    {
        /**
         * An instance of SelectOneToManyCommand to select the associated
         * entities using the id value of the owning entity as a parameter to
         * the FK in the 'where clause'.
         */
        public var selectCommand:SelectManyToManyCommand;

        /**
         * An instance of SelectManyToManyKeysCommand to select the FK values
         * relating to the list of associated entities.
         */
        public var selectManyToManyKeysCmd:SelectManyToManyKeysCommand;

        /**
         * An instance of InsertCommand, which creates a row in the association
         * table to create a link across the many-to-many association.
         */
        public var insertCommand:InsertCommand;

        /**
         * An instance of UpdateCommand, which updates the index column for an
         * indexed many-to-many association.
         */
        public var updateCommand:UpdateCommand;

        public var createSyncCmd:CreateSyncCommand;

        public var createAsynCmd:CreateAsynCommand;

        private var _associationTable:String;

        /**
         * Association table name
         */
        public function set associationTable(value:String):void
        {
            _associationTable = value;
        }

        public function get associationTable():String
        {
            return _associationTable;
        }

        public function ManyToManyAssociation(hash:Object=null)
        {
            super(hash);
        }

    }
}