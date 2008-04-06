package ormtest.model
{
	[Bindable]
	public class Person
	{
		[Id]
		[Column(name="id")]
		public var id:int;
		
		public var emailAddr:String;

	}
}