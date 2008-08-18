package nz.co.codec.flexorm.util
{
    import mx.collections.ArrayCollection;

    import nz.co.codec.flexorm.EntityManager;

    public dynamic class PersistentEntity
    {
        private static var em:EntityManager = EntityManager.instance;

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