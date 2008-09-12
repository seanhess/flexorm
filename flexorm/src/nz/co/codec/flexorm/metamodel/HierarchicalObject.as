package nz.co.codec.flexorm.metamodel
{
    public class HierarchicalObject implements IHierarchicalObject
    {
        private var _lft:int = 0;

        private var _rgt:int = 1;

        public function set lft(value:int):void
        {
            _lft = value;
        }

        public function get lft():int
        {
            return _lft;
        }

        public function set rgt(value:int):void
        {
            _rgt = value;
        }

        public function get rgt():int
        {
            return _rgt;
        }

    }
}