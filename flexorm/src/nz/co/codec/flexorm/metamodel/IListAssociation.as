package nz.co.codec.flexorm.metamodel
{
    public interface IListAssociation
    {
        function get ownerEntity():Entity;

        function get associatedEntity():Entity;

    }
}