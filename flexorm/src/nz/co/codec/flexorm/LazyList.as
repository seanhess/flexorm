package nz.co.codec.flexorm
{
	import mx.collections.ArrayCollection;
	import mx.collections.ArrayList;
	
	import nz.co.codec.flexorm.metamodel.IListAssociation;
	import nz.co.codec.flexorm.metamodel.ManyToManyAssociation;
	import nz.co.codec.flexorm.metamodel.OneToManyAssociation;

	public class LazyList extends ArrayList
	{
		private var em:EntityManager;
		
		private var a:IListAssociation;
		
		private var id:int;
		
		public var loaded:Boolean = false;
		
		public function LazyList(em:EntityManager, a:IListAssociation, id:int, source:Array=null)
		{
			super(source);
			if (source) loaded = true;
			this.em = em;
			this.a = a;
			this.id = id;
		}
		
		override public function get source():Array
		{
			if (!loaded)
			{
				if (a is OneToManyAssociation)
				{
					var otmAssociations:ArrayCollection = em.loadOneToManyAssociation(OneToManyAssociation(a), id);
					if (otmAssociations)
					{
						super.source = otmAssociations.toArray();
					}
				}
				else if (a is ManyToManyAssociation)
				{
					var mtmAssociations:ArrayCollection = em.loadManyToManyAssociation(ManyToManyAssociation(a), id);
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