package ormtest.model
{
	import mx.core.IUID;
	
	[Bindable]
	public dynamic class Organisation implements IUID
	{
		[Id]
		public var id:int;
		
		public var name:String;
		
		[Transient]
		public function get uid():String
		{
			return id.toString();
		}
		
		public function set uid(value:String):void
		{
			id = int(value);
		}

	}
}