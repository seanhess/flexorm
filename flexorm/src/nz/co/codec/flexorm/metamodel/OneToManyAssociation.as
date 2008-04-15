package nz.co.codec.flexorm.metamodel
{
	import nz.co.codec.flexorm.command.SelectCommand;
	
	public class OneToManyAssociation extends Association implements IListAssociation
	{
		private var _selectCommand:SelectCommand;
		
		public var lazy:Boolean = false;
		
		public function OneToManyAssociation(hash:Object = null)
		{
			super(hash);
		}
		
		/**
		 * an instance of SelectOneToManyCommand to select
		 * the associated entities using the id value of the
		 * owning entity as a parameter to the FK in the
		 * 'where clause'
		 */
		public function set selectCommand(value:SelectCommand):void
		{
			_selectCommand = value;
		}
		
		public function get selectCommand():SelectCommand
		{
			return _selectCommand;
		}
		
	}
}