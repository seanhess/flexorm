package nz.co.codec.flexorm
{
    import mx.collections.ArrayCollection;
    import mx.collections.ArrayList;

    import nz.co.codec.flexorm.metamodel.IListAssociation;
    import nz.co.codec.flexorm.metamodel.ManyToManyAssociation;
    import nz.co.codec.flexorm.metamodel.OneToManyAssociation;

    public class LazyList extends ArrayList
    {
        private var _em:EntityManager;

        private var _a:IListAssociation;

        private var _keyMap:Object;

        public var loaded:Boolean = false;

        public function LazyList(em:EntityManager, a:IListAssociation, keyMap:Object, source:Array=null)
        {
            super(source);
            if (source)
                loaded = true;
            _em = em;
            _a = a;
            _keyMap = keyMap;
        }

        override public function get source():Array
        {
            if (!loaded)
            {
                if (_a is OneToManyAssociation)
                {
                    var otmAssociations:ArrayCollection = _em.loadOneToManyAssociation(OneToManyAssociation(_a), _keyMap);
                    if (otmAssociations)
                    {
                        super.source = otmAssociations.toArray();
                    }
                }
                else if (_a is ManyToManyAssociation)
                {
                    var mtmAssociations:ArrayCollection = _em.loadManyToManyAssociation(ManyToManyAssociation(_a), _keyMap);
                    if (mtmAssociations)
                    {
                        super.source = mtmAssociations.toArray();
                    }
                }
            }
            loaded = true;
            return super.source;
        }

    }
}