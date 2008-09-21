package nz.co.codec.flexorm
{
    import nz.co.codec.flexorm.command.InsertCommand;
    import nz.co.codec.flexorm.metamodel.Entity;
    import nz.co.codec.flexorm.metamodel.ListAssociation;

    internal class SaveRecursiveArgs
    {
        internal var name:String;

        internal var a:ListAssociation;

        internal var associatedEntity:Entity;

        internal var hasCompositeKey:Boolean;

        internal var idMap:Object;

        internal var mtmInsertCommand:InsertCommand;

        internal var indexValue:int;

        internal var subInsertCommand:InsertCommand;

        internal var entityType:String;

        internal var fkProperty:String;

        internal var lft:int = -1;

        internal var rootEval:Boolean = false;

        internal var rootLft:int;

        internal var rootSpread:int;

        internal var ownerClass:Class;

    }
}