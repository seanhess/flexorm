package ormtest.model
{
	[Bindable]
	[Table(name="orders")]
	public class Order
	{
		[Id]
		public var id:int;
		
		[ManyToOne(inverse="true")]
		public var contact:Contact;
		
		[Column(name="order_date")]
		public var orderDate:Date;
		
		public var item:String;

	}
}