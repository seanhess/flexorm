package nz.co.codec.flexorm.metamodel
{
	import nz.co.codec.flexorm.command.SQLCommand;
	
	public interface IListAssociation
	{
		function get column():String;
		
		function get associatedEntity():Entity;
		
	}
}