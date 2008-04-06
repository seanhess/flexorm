package nz.co.codec.flexorm.metamodel
{
	import nz.co.codec.flexorm.command.SelectCommand;
	
	public class OneToManyAssociation extends Association
	{
		/**
		 * an instance of SelectOneToManyCommand to select
		 * the associated entities using the id value of the
		 * owning entity as a parameter to the FK in the
		 * 'where clause'
		 */
		public var selectCommand:SelectCommand;
		
		public function OneToManyAssociation(hash:Object = null)
		{
			super(hash);
		}
		
	}
}