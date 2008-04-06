package nz.co.codec.flexorm.metamodel
{
	import nz.co.codec.flexorm.command.DeleteCommand;
	import nz.co.codec.flexorm.command.InsertCommand;
	import nz.co.codec.flexorm.command.SelectManyToManyCommand;
	import nz.co.codec.flexorm.command.SelectManyToManyIndicesCommand;
	
	public class ManyToManyAssociation extends Association
	{
		private var _associationTable:String;
		
		/**
		 * database column name of the FK in the association
		 * table which links to the associated entity
		 */
		public var joinColumn:String;
		
		/**
		 * an instance of SelectOneToManyCommand to select the associated
		 * entities using the id value of the owning entity as a parameter
		 * to the FK in the 'where clause'
		 */
		public var selectCommand:SelectManyToManyCommand;
		
		/**
		 * an instance of SelectManyToManyIndicesCommand to select
		 * the FK values relating to the list of associated entities
		 */
		public var selectIndicesCommand:SelectManyToManyIndicesCommand;
		
		/**
		 * an instance of InsertManyToManyCommand which creates a row in the
		 * association table to create a link across the many-to-many
		 * association
		 */
		public var insertCommand:InsertCommand;
		
		/**
		 * an instance of DeleteCommand to remove a many-to-many association
		 * (not the associated entity)
		 */
		public var deleteCommand:DeleteCommand;
		
		public function ManyToManyAssociation(hash:Object = null)
		{
			super(hash);
		}
		
		/**
		 * association table name
		 */
		public function set associationTable(value:String):void
		{
			_associationTable = value;
		}
		
		public function get associationTable():String
		{
			if (!_associationTable)
			{
				_associationTable = ownerEntity.classname + "_" + associatedEntity.classname;
			}
			return _associationTable;
		}

	}
}