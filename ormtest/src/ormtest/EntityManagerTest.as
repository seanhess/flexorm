package ormtest
{
	import flash.errors.SQLError;
	import flash.events.Event;
	
	import flexunit.framework.TestCase;
	import flexunit.framework.TestSuite;
	
	import mx.collections.ArrayCollection;
	import mx.rpc.Responder;
	
	import nz.co.codec.flexorm.EntityManager;
	import nz.co.codec.flexorm.IEntityManager;
	
	import ormtest.model.Contact;
	import ormtest.model.Order;
	import ormtest.model.Organisation;
	import ormtest.model.Person;
	import ormtest.model.Role;
	
	public class EntityManagerTest extends TestCase
	{
		private static var em:IEntityManager = EntityManager.instance;
		
		public static function suite():TestSuite
		{
			em.debugLevel = 1;
			var ts:TestSuite = new TestSuite();
			ts.addTest(new EntityManagerTest("testSaveSimpleObject"));
			ts.addTest(new EntityManagerTest("testFindAll"));
			ts.addTest(new EntityManagerTest("testSaveManyToOneAssociation"));
			ts.addTest(new EntityManagerTest("testSaveOneToManyAssociations"));
			ts.addTest(new EntityManagerTest("testSaveManyToManyAssociation"));
			ts.addTest(new EntityManagerTest("testDelete"));
			ts.addTest(new EntityManagerTest("testCascadeSaveUpdate"));
			ts.addTest(new EntityManagerTest("testInheritance1"));
			ts.addTest(new EntityManagerTest("testInheritance2"));
			ts.addTest(new EntityManagerTest("testTransaction"));
			ts.addTest(new EntityManagerTest("testAlternateAPI"));
			return ts;
		}
		
		public function EntityManagerTest(methodName:String=null)
		{
			super(methodName);
		}
		
		public function testSaveSimpleObject():void
		{
			trace("\nTest Save Simple Object");
			trace("=======================");
			var organisation:Organisation = new Organisation();
			organisation.name = "Codec Group Limited";
			em.save(organisation);
			
			var loadedOrganisation:Organisation = em.loadItem(Organisation, organisation.id) as Organisation;
			assertEquals(loadedOrganisation.name, "Codec Group Limited");
		}
		
		public function testFindAll():void
		{
			trace("\nTest Find All");
			trace("=============");
			var organisation:Organisation = new Organisation();
			organisation.name = "Adobe";
			em.save(organisation);
			
			var organisations:ArrayCollection = em.findAll(Organisation);
			assertEquals(organisations.length, 2);
		}
		
		public function testSaveManyToOneAssociation():void
		{
			trace("\nTest Save Many To One Association");
			trace("=================================");
			var organisation:Organisation = new Organisation();
			organisation.name = "Apple";
			// since Organisation has cascade="none" on Contact
			em.save(organisation);
			
			var contact:Contact = new Contact();
			contact.name = "Steve";
			contact.organisation = organisation;
			em.save(contact);
			
			var loadedContact:Contact = em.loadItem(Contact, contact.id) as Contact;
			assertNotNull(loadedContact);
			assertNotNull(loadedContact.organisation);
			assertEquals(loadedContact.organisation.name, "Apple");
		}
		
		public function testSaveOneToManyAssociations():void
		{
			trace("\nTest Save One To Many Associations");
			trace("==================================");
			var orders:ArrayCollection = new ArrayCollection();
			
			var order1:Order = new Order();
			order1.item = "Flex Builder 3";
			
			var order2:Order = new Order();
			order2.item = "CS3 Fireworks";
			
			orders.addItem(order1);
			orders.addItem(order2);
			
			var contact:Contact = new Contact();
			contact.name = "Greg";
			contact.orders = orders;
			em.save(contact);
			
			var loadedContact:Contact = em.loadItem(Contact, contact.id) as Contact;
			assertEquals(loadedContact.orders.length, 2);
		}
		
		public function testSaveManyToManyAssociation():void
		{
			trace("\nTest Save Many To Many Associations");
			trace("===================================");
			var roles:ArrayCollection = new ArrayCollection();
			
			var role1:Role = new Role();
			role1.name = "Project Manager";
			
			var role2:Role = new Role();
			role2.name = "Business Analyst";
			
			roles.addItem(role1);
			roles.addItem(role2);
			
			var contact:Contact = new Contact();
			contact.name = "Shannon";
			contact.roles = roles;
			em.save(contact);
			
			var loadedContact:Contact = em.loadItem(Contact, contact.id) as Contact;
			assertEquals(loadedContact.roles.length, 2);
		}
		
		public function testDelete():void
		{
			trace("\nTest Delete");
			trace("===========");
			var organisation:Organisation = new Organisation();
			organisation.name = "Datacom";
			em.save(organisation);
			
			em.remove(organisation);
			var loadedOrganisation:Organisation = em.loadItem(Organisation, organisation.id) as Organisation;
			assertNull(loadedOrganisation);
		}
		
		public function testCascadeSaveUpdate():void
		{
			trace("\nTest Cascade Save Update");
			trace("========================");
			var orders:ArrayCollection = new ArrayCollection();
			
			var order1:Order = new Order();
			order1.item = "Bach";
			
			var order2:Order = new Order();
			order2.item = "BMW";
			
			orders.addItem(order1);
			orders.addItem(order2);
			
			var contact:Contact = new Contact();
			contact.name = "Jen";
			contact.orders = orders; // cascade="save-update"
			em.save(contact);
			
			var orderId:int = order2.id;
			
			// verify that cascade save-update works
			assertTrue(orderId > 0);
			
			// since the orders association is cascade="save-update" only
//			for each(var o:Order in contact.orders)
//			{
//				em.remove(o);
//			}
			em.remove(contact);
			
			// verify that cascade delete is not in effect
			
			// !!! Yes, but foreign key constraint violation is
			// so FK constraint has been swicthed off using constrain="false"
			var loadedOrder:Order = em.loadItem(Order, orderId) as Order;
			assertEquals(loadedOrder.item, "BMW");
		}
		
		public function testInheritance1():void
		{
			trace("\nTest Inheritance 1");
			trace("==================");
			var person:Person = new Person();
			person.emailAddr = "person@acme.com";
			em.save(person);
			
			var loadedPerson:Person = em.loadItem(Person, person.id) as Person;
			assertEquals(loadedPerson.emailAddr, "person@acme.com");
		}
		
		public function testInheritance2():void
		{
			trace("\nTest Inheritance 2");
			trace("==================");
			var contact:Contact = new Contact();
			contact.name = "Bill";
			contact.emailAddr = "bill@ms.com";
			em.save(contact);
			
			var loadedContact:Contact = em.loadItem(Contact, contact.id) as Contact;
			assertEquals(loadedContact.emailAddr, "bill@ms.com");
			
			var loadedPerson:Person = em.loadItem(Person, contact.id) as Person;
			assertEquals(loadedPerson.emailAddr, "bill@ms.com");
		}
		
		public function testTransaction():void
		{
			trace("\nTest Transactions");
			trace("=================");
			var organisation:Organisation = new Organisation();
			organisation.name = "Google";
			em.save(organisation);
			
			var contact:Contact = new Contact();
			contact.name = "Sergey";
			contact.organisation = organisation;
			em.save(contact);
			
			var success:Boolean;
			var responder:Responder = new Responder(
				function(event:Event):void
				{
					trace(event);
					success = true;
				},
				function(error:SQLError):void
				{
					trace("transaction failed: " + error);
					success = false;
				});
			
			em.startTransaction(responder);
			em.remove(organisation);
			em.endTransaction();
			
			// The transaction is expected to fail with a
			// foreign key constraint violation
			assertEquals(success, false);
		}
		
		public function testAlternateAPI():void
		{
			em.makePersistent(Organisation);
			
			var organisation:Organisation = new Organisation();
			organisation.name = "Datacom";
			organisation.save();
			
			var loadedOrganisation:Organisation = em.loadItem(Organisation, organisation.id) as Organisation;
			assertEquals(loadedOrganisation.name, "Datacom");
		}
		
	}
}