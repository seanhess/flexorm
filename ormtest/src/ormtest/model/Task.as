package ormtest.model
{
    import flash.events.Event;
    import flash.events.EventDispatcher;

    import mx.collections.ArrayCollection;
    import mx.collections.IList;
    import mx.events.CollectionEvent;

    [Event(name="amountChange")]

    [Bindable]
    public class Task extends EventDispatcher
    {
        private var _amount:Number;

        private var _children:IList;

        public function Task()
        {
            name = "New Task";
            amount = 10;
        }

        public var id:int;

        public var name:String;

        [ManyToOne(name="parent_id", inverse="true")]
        public var parent:Task;

        public function set amount(value:Number):void
        {
            _amount = value;
            dispatchEvent(new Event("amountChange"));
        }

        public function get amount():Number
        {
            return _amount;
        }

        private function updateAmount(event:Event):void
        {
            if (_children && _children.length > 0)
            {
                var amt:Number = 0;
                for each(var child:Task in _children)
                {
                    amt += child.amount;
                }
                amount = amt;
            }
        }

        [OneToMany(type="ormtest.model.Task", fkColumn="parent_id", cascade="save-update", indexed="true", lazy="true")]
        public function set children(value:IList):void
        {
            _children = value;
            for each(var child:Task in value)
            {
                child.addEventListener("amountChange", updateAmount);
            }
            _children.addEventListener(CollectionEvent.COLLECTION_CHANGE, updateAmount);
            updateAmount(new Event("amountChange"));
        }

        public function get children():IList
        {
            return _children;
        }

        public function addChild(child:Task):void
        {
            if (_children == null)
            {
                _children = new ArrayCollection();
                _children.addEventListener(CollectionEvent.COLLECTION_CHANGE, updateAmount);
            }
            _children.addItem(child);
            child.addEventListener("amountChange", updateAmount);
            child.parent = this;
        }

        public function removeChild(child:Task):void
        {
            if (_children)
            {
                _children.removeItemAt(_children.getItemIndex(child));
                child.removeEventListener("amountChange", updateAmount);
            }
        }

    }
}