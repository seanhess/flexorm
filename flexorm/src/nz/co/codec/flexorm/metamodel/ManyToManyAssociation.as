package nz.co.codec.flexorm.metamodel
{
    import nz.co.codec.flexorm.command.CreateAsynCommand;
    import nz.co.codec.flexorm.command.CreateSynCommand;
    import nz.co.codec.flexorm.command.InsertCommand;
    import nz.co.codec.flexorm.command.SelectCommand;
    import nz.co.codec.flexorm.command.UpdateCommand;

    public class ManyToManyAssociation extends ListAssociation
    {
        /**
         * An instance of SelectCommand to select the associated entities
         * using the id value of the owning entity as a parameter to the FK
         * in the 'where clause'.
         */
        public var selectCommand:SelectCommand;

        /**
         * An instance of SelectCommand to select the FK values relating to the
         * list of associated entities.
         */
        public var selectManyToManyKeysCommand:SelectCommand;

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

        public var createSynCommand:CreateSynCommand;

        public var createAsynCommand:CreateAsynCommand;

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