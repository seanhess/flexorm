package nz.co.codec.flexorm.metamodel
{
	import mx.collections.ArrayCollection;
	import mx.utils.StringUtil;
	
	import nz.co.codec.flexorm.command.DeleteCommand;
	import nz.co.codec.flexorm.command.FindAllCommand;
	import nz.co.codec.flexorm.command.InsertCommand;
	import nz.co.codec.flexorm.command.SelectCommand;
	import nz.co.codec.flexorm.command.UpdateCommand;
	
	public class Entity
	{
		private var _cls:Class;
		
		private var _classname:String;
		
		private var _fkColumn:String;
		
		private var _table:String;
		
		private var _fields:ArrayCollection;
		
		private var _manyToOneAssociations:ArrayCollection;
		
		private var _oneToManyAssociations:ArrayCollection;
		
		private var _oneToManyInverseAssociations:ArrayCollection;
		
		private var _manyToManyAssociations:ArrayCollection;
		
		private var _manyToManyInverseAssociations:ArrayCollection;
		
		public var superEntity:Entity;
		
		/**
		 * info about the id property of the entity
		 */
		public var identity:Identity;
		
		public var findAllCommand:FindAllCommand;
		
		public var selectCommand:SelectCommand;
		
		public var insertCommand:InsertCommand;
		
		public var updateCommand:UpdateCommand;
		
		public var deleteCommand:DeleteCommand;
		
		/**
		 * flag to indicate whether the loading of metadata
		 * for an entity has been completed
		 */
		public var initialisationComplete:Boolean;
		
		public function Entity(cls:Class)
		{
			_cls = cls;
			_classname = getClassName(cls);
			_fkColumn = getFkColumn(_classname);
			_table = _classname;
			initialisationComplete = false;
		}
		
		public function get cls():Class
		{
			return _cls;
		}
		
		public function get classname():String
		{
			return _classname;
		}
		
		public function get fkColumn():String
		{
			return _fkColumn;
		}
		
		/**
		 * database table name; defaults to entity class name
		 */
		public function set table(value:String):void
		{
			if (value && StringUtil.trim(value).length > 0)
			{
				_table = value;
			}
		}
		
		public function get table():String
		{
			return _table;
		}
		
		public function set fields(value:ArrayCollection):void
		{
			_fields = value;
		}
		
		public function get fields():ArrayCollection
		{
			if (!_fields)
			{
				_fields = new ArrayCollection();
			}
			return _fields;
		}
		
		public function addField(value:Field):void
		{
			if (!_fields)
			{
				_fields = new ArrayCollection();
			}
			_fields.addItem(value);
		}
		
		public function set manyToOneAssociations(value:ArrayCollection):void
		{
			_manyToOneAssociations = value;
			for each (var a:Association in value)
			{
				a.ownerEntity = this;
			}
		}
		
		public function get manyToOneAssociations():ArrayCollection
		{
			return _manyToOneAssociations;
		}
		
		public function addManyToOneAssociation(value:Association):void
		{
			if (!_manyToOneAssociations)
			{
				_manyToOneAssociations = new ArrayCollection();
			}
			_manyToOneAssociations.addItem(value);
			value.ownerEntity = this;
		}
		
		public function set oneToManyAssociations(value:ArrayCollection):void
		{
			_oneToManyAssociations = value;
			for each (var a:OneToManyAssociation in value)
			{
				a.ownerEntity = this;
			}
		}
		
		public function get oneToManyAssociations():ArrayCollection
		{
			return _oneToManyAssociations;
		}
		
		public function addOneToManyAssociation(value:OneToManyAssociation):void
		{
			if (!_oneToManyAssociations)
			{
				_oneToManyAssociations = new ArrayCollection();
			}
			_oneToManyAssociations.addItem(value);
			value.ownerEntity = this;
		}
		
		/**
		 * a copy of the oneToManyAssociation set on
		 * the map of the associated entity
		 */
		public function set oneToManyInverseAssociations(value:ArrayCollection):void
		{
			_oneToManyInverseAssociations = value;
			for each (var a:OneToManyAssociation in value)
			{
				a.ownerEntity = this;
			}
		}
		
		public function get oneToManyInverseAssociations():ArrayCollection
		{
			return _oneToManyInverseAssociations;
		}
		
		public function addOneToManyInverseAssociation(value:OneToManyAssociation):void
		{
			if (!_oneToManyInverseAssociations)
			{
				_oneToManyInverseAssociations = new ArrayCollection();
			}
			_oneToManyInverseAssociations.addItem(value);
			value.ownerEntity = this;
		}
		
		public function set manyToManyAssociations(value:ArrayCollection):void
		{
			_manyToManyAssociations = value;
			for each (var a:ManyToManyAssociation in value)
			{
				a.ownerEntity = this;
			}
		}
		
		public function get manyToManyAssociations():ArrayCollection
		{
			return _manyToManyAssociations;
		}
		
		public function addManyToManyAssociation(value:ManyToManyAssociation):void
		{
			if (!_manyToManyAssociations)
			{
				_manyToManyAssociations = new ArrayCollection();
			}
			_manyToManyAssociations.addItem(value);
			value.ownerEntity = this;
		}
		
		public function set manyToManyInverseAssociations(value:ArrayCollection):void
		{
			_manyToManyInverseAssociations = value;
			for each (var a:ManyToManyAssociation in value)
			{
				a.ownerEntity = this;
			}
		}
		
		public function get manyToManyInverseAssociations():ArrayCollection
		{
			return _manyToManyInverseAssociations;
		}
		
		public function addManyToManyInverseAssociation(value:ManyToManyAssociation):void
		{
			if (!_manyToManyInverseAssociations)
			{
				_manyToManyInverseAssociations = new ArrayCollection();
			}
			_manyToManyInverseAssociations.addItem(value);
			value.ownerEntity = this;
		}
		
		private function getClassName(c:Class):String
		{
			var className:String = String(c);
			var len:int = className.length;
			var x:int = className.lastIndexOf(" ") + 1;
			return className.substr(x, 1).toLowerCase() +
				className.substring(x + 1, len - 1);
		}
		
		private function getFkColumn(classname:String):String
		{
			return classname + "Id";
		}

	}
}