package nz.co.codec.flexorm.metamodel
{
	/**
	 * info about the id property of the entity
	 */
	public class Identity
	{
		/**
		 * property name
		 */
		public var property:String;
		
		/**
		 * database column name
		 */
		public var column:String;
		
		public function Identity(hash:Object = null)
		{
			for (var key:String in hash)
			{
				if (hasOwnProperty(key))
				{
					this[key] = hash[key];
				}
			}
		}

	}
}