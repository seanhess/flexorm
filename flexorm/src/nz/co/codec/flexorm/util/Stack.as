package nz.co.codec.flexorm.util
{
    public class Stack
    {
        private var data:Array;

        public function Stack()
        {
            data = [];
        }

        public function push(value:Object):void
        {
            data.push(value);
        }

        public function pop():Object
        {
            return data.pop();
        }

        public function getLastItem():Object
        {
            return data[data.length - 1];
        }

    }
}