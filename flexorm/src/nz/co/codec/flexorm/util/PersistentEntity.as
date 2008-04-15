package nz.co.codec.flexorm.util
{
	import mx.collections.ArrayCollection;
	
	import nz.co.codec.flexorm.EntityManager;
	import nz.co.codec.flexorm.IEntityManager;
	
	public dynamic class PersistentEntity
	{
		private static var em:IEntityManager = EntityManager.instance;
		
		/**
		 * 'this' refers to the object of the class that this method
		 * is called from
		 */
		prototype.save = function():void
		{
			em.save(this);
		};
		
		prototype.remove = function():void
		{
			em.remove(this);
		};

	}
}