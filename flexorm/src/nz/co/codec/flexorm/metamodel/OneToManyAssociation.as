package nz.co.codec.flexorm.metamodel
{
    import nz.co.codec.flexorm.command.SelectCommand;

    public class OneToManyAssociation extends ListAssociation
    {
        /**
         * An instance of SelectCommand to select the associated entities using
         * the keys of the owning entity as parameters to the FKs in the 'where
         * clause'.
         */
        public var selectCommand:SelectCommand;

        public function OneToManyAssociation(hash:Object=null)
        {
            super(hash);
        }

    }
}