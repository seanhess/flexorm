package nz.co.codec.flexorm.metamodel
{
	import mx.utils.StringUtil;
	
	import nz.co.codec.flexorm.CascadeType;
	
	public class Association
	{
		/**
		 * association property name
		 */
		public var property:String;
		
		private var _column:String;
		
		private var _associatedEntity:Entity;
		
		/**
		 * true or false if this association is the inverse
		 * end of a bidirectional one-to-many association
		 */
		public var inverse:Boolean;
		
		public var ownerEntity:Entity;
		
		private var _cascadeType:String;
		
		public var constrain:Boolean;
		
		public function Association(hash:Object = null)
		{
			inverse = false;
			cascadeType = CascadeType.SAVE_UPDATE;
			for (var key:String in hash)
			{
				if (hasOwnProperty(key))
				{
					this[key] = hash[key];
				}
			}
		}
		
		/**
		 * database column name of FK in table of associated
		 * entity (= class name of owning entity + 'Id', e.g.
		 * 'contactId'),
		 * 
		 * or,
		 * 
		 * in the case of a many-to-many association, the
		 * database column name of the FK in the association
		 * table which links to the owner entity
		 */
		public function set column(value:String):void
		{
			_column = value;
		}
		
		public function get column():String
		{
			return _column;
		}
		
		/**
		 * Entity definition of class of associated object
		 */
		public function set associatedEntity(value:Entity):void
		{
			_associatedEntity = value;
		}
		
		public function get associatedEntity():Entity
		{
			return _associatedEntity;
		}
		
		/**
		 * valid values are:
		 *   "save-update"
		 *       save or update the associated entities on save of
		 *       the owning entity,
		 *   "delete"
		 *       delete the associated entities on deletion of
		 *       the owning entity,
		 *   "all"
		 *       support cascade save, update, and delete, and
		 *   "none"
		 *       do not cascade any changes to the associated entities
		 */
		public function set cascadeType(value:String):void
		{
			if (value && StringUtil.trim(value).length > 0)
			{
				_cascadeType = value;
			}
		}
		
		public function get cascadeType():String
		{
			return _cascadeType;
		}

	}
}