package ormtest.model
{
    [Bindable]
    [Table(name="purchase_orders")]
    public class Order
    {
        [Id]
        public var id:int;

        [ManyToOne(name="my_contact_id", inverse="true")]
        public var contact:Contact;

        [Column(name="order_date")]
        public var orderDate:Date;

        public var item:String;

    }
}