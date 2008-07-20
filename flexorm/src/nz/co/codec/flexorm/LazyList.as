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

        private var _loaded:Boolean = true;

        public function LazyList(em:EntityManager, a:IListAssociation, keyMap:Object)
        {
            super();
            _em = em;
            _a = a;
            _keyMap = keyMap;
        }

        public function initialise():void
        {
            _loaded = false;
        }

        public function get loaded():Boolean
        {
            return _loaded;
        }

        override public function get source():Array
        {
            if (!_loaded)
            {
                _loaded = true;
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
            return super.source;
        }

    }
}