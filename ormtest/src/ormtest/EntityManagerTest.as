package ormtest
{
    import flexunit.framework.TestCase;
    import flexunit.framework.TestSuite;

    import mx.collections.ArrayCollection;
    import mx.collections.IList;

    import nz.co.codec.flexorm.EntityManager;
    import nz.co.codec.flexorm.criteria.Criteria;
    import nz.co.codec.flexorm.criteria.Junction;
    import nz.co.codec.flexorm.criteria.Sort;

    import ormtest.model.A;
    import ormtest.model.B;
    import ormtest.model.C;
    import ormtest.model.Contact;
    import ormtest.model.D;
    import ormtest.model.E;
    import ormtest.model.F;
    import ormtest.model.G;
    import ormtest.model.Gallery;
    import ormtest.model.Lesson;
    import ormtest.model.Order;
    import ormtest.model.Organisation;
    import ormtest.model.Part;
    import ormtest.model.Resource;
    import ormtest.model.Role;
    import ormtest.model.Schedule;
    import ormtest.model.Student;
    import ormtest.model.Vehicle;
    import ormtest.model2.Person;

    public class EntityManagerTest extends TestCase
    {
        private static var em:EntityManager = EntityManager.instance;

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
            ts.addTest(new EntityManagerTest("testCompositeKey"));
            ts.addTest(new EntityManagerTest("testCompositeKeyOneToMany"));
            ts.addTest(new EntityManagerTest("testOneToManyIndexedCollection"));
            ts.addTest(new EntityManagerTest("testManyToManyIndexedCollection"));
            ts.addTest(new EntityManagerTest("testDeepCompositeKeyNesting"));
            ts.addTest(new EntityManagerTest("testSaveUntypedObject"));
            ts.addTest(new EntityManagerTest("testSaveManyToOneUntypedObject"));
            ts.addTest(new EntityManagerTest("testSaveOneToManyUntypedObject"));
            ts.addTest(new EntityManagerTest("testRecursiveJoin"));
            ts.addTest(new EntityManagerTest("testLazyLoading"));
            ts.addTest(new EntityManagerTest("testCriteriaAPI"));
            ts.addTest(new EntityManagerTest("testCriteriaAPI2"));
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
            organisation.name = "Codec Software Limited";
            em.save(organisation);

            var loadedOrganisation:Organisation = em.load(Organisation, organisation.id) as Organisation;
            assertEquals(loadedOrganisation.name, "Codec Software Limited");
        }

        public function testFindAll():void
        {
            trace("\nTest Find All");
            trace("=============");
            var adobe:Organisation = new Organisation();
            adobe.name = "Adobe";
            em.save(adobe);
            var fogCreek:Organisation = new Organisation();
            fogCreek.name = "Fog Creek";
            em.save(fogCreek);

            var organisations:ArrayCollection = em.findAll(Organisation);
            assertEquals(organisations.length, 3);
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

            var loadedContact:Contact = em.load(Contact, contact.id) as Contact;
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

            var loadedContact:Contact = em.load(Contact, contact.id) as Contact;
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

            var loadedContact:Contact = em.load(Contact, contact.id) as Contact;
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
            var loadedOrganisation:Organisation = em.load(Organisation, organisation.id) as Organisation;
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
            // so FK constraint has been switched off using constrain="false"
            var loadedOrder:Order = em.load(Order, orderId) as Order;
            assertEquals(loadedOrder.item, "BMW");
        }

        public function testInheritance1():void
        {
            trace("\nTest Inheritance 1");
            trace("==================");
            var person:Person = new Person();
            person.emailAddr = "person@acme.com";
            em.save(person);

            var loadedPerson:Person = em.load(Person, person.id) as Person;
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

            var loadedContact:Contact = em.load(Contact, contact.id) as Contact;
            assertEquals(loadedContact.emailAddr, "bill@ms.com");

            var loadedPerson:Person = em.load(Person, contact.id) as Person;
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
            em.startTransaction();
/*
            em.startTransaction(new Responder(
                function(data:Object):void
                {
                    trace("successful transaction: " + data);
                    success = true;
                },

                function(info:Object):void
                {
                    trace("transaction failed: " + info);
                    success = false;
                }
            ));
*/
            em.remove(organisation);
            em.endTransaction();

            // The transaction is expected to fail with a
            // foreign key constraint violation
//			assertEquals(success, false);
        }

        public function testAlternateAPI():void
        {
            trace("\nTest Alternate API");
            trace("==================");
            em.makePersistent(Organisation);

            var organisation:Organisation = new Organisation();
            organisation.name = "Datacom";
            organisation.save();

            var loadedOrganisation:Organisation = em.load(Organisation, organisation.id) as Organisation;
            assertEquals(loadedOrganisation.name, "Datacom");
        }

        public function testCompositeKey():void
        {
            trace("\nTest Composite Key");
            trace("==================");
            var student:Student = new Student();
            student.name = "Mark";
            em.save(student);

            var lesson:Lesson = new Lesson();
            lesson.name = "Piano";
            em.save(lesson);

            var schedule:Schedule = new Schedule();
            schedule.student = student;
            schedule.lesson = lesson;
            var today:Date = new Date();
            schedule.lessonDate = today;
            em.save(schedule);

            var loadedSchedule:Schedule = em.loadItemByCompositeKey(Schedule, [student, lesson]) as Schedule;

            // date.time comparison shows difference - could ms difference
            // when loading to/from database
//			assertEquals(loadedSchedule.date, today);

            assertEquals(loadedSchedule.lessonDate.fullYear, today.fullYear);
            assertEquals(loadedSchedule.lessonDate.month, today.month);
            assertEquals(loadedSchedule.lessonDate.date, today.date);
        }

        public function testCompositeKeyOneToMany():void
        {
            trace("\nTest Composite Key with One-to-many");
            trace("===================================");
            var student:Student = new Student();
            student.name = "Shannon";
            em.save(student);

            var lesson:Lesson = new Lesson();
            lesson.name = "Viola";
            em.save(lesson);

            var schedule:Schedule = new Schedule();
            schedule.student = student;
            schedule.lesson = lesson;
            var today:Date = new Date();
            schedule.lessonDate = today;

            var stand:Resource = new Resource();
            stand.name = "Stand";

            var score:Resource = new Resource();
            score.name = "Mozart";

            var resources:ArrayCollection = new ArrayCollection();
            resources.addItem(stand);
            resources.addItem(score);
            schedule.resources = resources;

            em.save(schedule);

            var loadedSchedule:Schedule = em.loadItemByCompositeKey(Schedule, [student, lesson]) as Schedule;

            assertEquals(loadedSchedule.resources.length, 2);
        }

        public function testOneToManyIndexedCollection():void
        {
            trace("\nTest One To Many Indexed Collection");
            trace("===================================");
            var orders:ArrayCollection = new ArrayCollection();

            var order1:Order = new Order();
            order1.item = "Macbook";

            var order2:Order = new Order();
            order2.item = "iPhone";

            orders.addItem(order1);
            orders.addItem(order2);

            var contact:Contact = new Contact();
            contact.name = "Mark";
            contact.orders = orders;
            em.save(contact);

            var loadedContact:Contact = em.load(Contact, contact.id) as Contact;
            assertEquals(loadedContact.orders[1].item, "iPhone");

            var orderList:IList = loadedContact.orders;
            orderList.addItemAt(orderList.removeItemAt(1), 0);
            em.save(loadedContact);

            var reloadedContact:Contact = em.load(Contact, contact.id) as Contact;
            assertEquals(reloadedContact.orders[1].item, "Macbook");
        }

        public function testManyToManyIndexedCollection():void
        {
            trace("\nTest Many To Many Indexed Collection");
            trace("====================================");
            var roles:ArrayCollection = new ArrayCollection();

            var role1:Role = new Role();
            role1.name = "Carpenter";

            var role2:Role = new Role();
            role2.name = "Sparky";

            roles.addItem(role1);
            roles.addItem(role2);

            var contact:Contact = new Contact();
            contact.name = "John";
            contact.roles = roles;
            em.save(contact);

            var loadedContact:Contact = em.load(Contact, contact.id) as Contact;
            assertEquals(loadedContact.roles[1].name, "Sparky");

            var roleList:IList = loadedContact.roles;
            roleList.addItemAt(roleList.removeItemAt(1), 0);
            em.save(loadedContact);

            var reloadedContact:Contact = em.load(Contact, contact.id) as Contact;
            assertEquals(reloadedContact.roles[1].name, "Carpenter");
        }

        public function testDeepCompositeKeyNesting():void
        {
            trace("\nTest Deep Composite Key Nesting");
            trace("===============================");
            var a:A = new A();
            a.name = "A";
            em.save(a);

            var b:B = new B();
            b.name = "B";
            em.save(b);

            var c:C = new C();
            c.name = "C";
            em.save(c);

            var d:D = new D();
            d.name = "D";
            em.save(d);

            var e:E = new E();
            e.a = a;
            e.b = b;
            e.name = "E";
            em.save(e);

            var f:F = new F();
            f.c = c;
            f.d = d;
            f.name = "F";
            em.save(f);

            var g:G = new G();
            g.e = e;
            g.f = f;
            g.name = "G";
            em.save(g);

            var loadedG:G = em.loadItemByCompositeKey(G, [e,f]) as G;
            assertEquals(loadedG.e.a.name, "A");
        }

        public function testSaveUntypedObject():void
        {
            trace("\nTest Save Untyped Object");
            trace("========================");
            var obj:Object = new Object();
            obj.name = "Test Object";

            var handle:int = em.save(obj, { name: "test" });
            var loadedObject:Object = em.loadDynamicObject("test", handle);
            assertEquals(loadedObject.name, "Test Object");
        }

        public function testSaveManyToOneUntypedObject():void
        {
            trace("\nTest Save Many To One Untyped Object");
            trace("====================================");
            var obj:Object = new Object();
            obj.name = "Test Object";

            var mto:Object = new Object();
            mto.name = "Many To One";
            obj.mto = mto;

            var handle:int = em.save(obj, { name: "test" });

            var loadedObject:Object = em.loadDynamicObject("test", handle);
            assertEquals(loadedObject.mto.name, "Many To One");
        }

        public function testSaveOneToManyUntypedObject():void
        {
            trace("\nTest Save One To Many Untyped Object");
            trace("====================================");
            var obj:Object = new Object();
            obj.name = "Test Object";

            var myList:IList = new ArrayCollection();

            var x:Object = new Object();
            x.name = "First";
            var another:Object = new Object();
            another.type = "some type";
            x.another = another;
            myList.addItem(x);

            var y:Object = new Object();
            y.name = "Second";
            myList.addItem(y);
            obj.myList = myList;

            var handle:int = em.save(obj, { name: "test" });

            var loadedObject:Object = em.loadDynamicObject("test", handle);
            assertEquals(loadedObject.myList[0].another.type, "some type");
        }

        public function testRecursiveJoin():void
        {
            trace("\nTest Recursive Join");
            trace("===================");

            var g1:Gallery = new Gallery();
            g1.name = "A";

            var g2:Gallery = new Gallery();
            g2.name = "B";

            var g3:Gallery = new Gallery();
            g3.name = "C";
            g3.parent = g2;
            g2.parent = g1;
            em.save(g3);

            var loadedGallery:Gallery = em.loadItem(Gallery, g3.id) as Gallery;
            assertEquals(loadedGallery.name, "C");
            assertEquals(loadedGallery.parent.parent.name, "A");
        }

        public function testLazyLoading():void
        {
            trace("\nTest Lazy Loading");
            trace("=================");

            var car:Vehicle = new Vehicle();
            car.name = "Car";

            var engine:Part = new Part();
            engine.name = "Engine";
            car.parts.addItem(engine);

            var wheel:Part = new Part();
            wheel.name = "Wheel";
            car.parts.addItem(wheel);

            em.save(car);

            var loadedCar:Vehicle = em.load(Vehicle, car.id) as Vehicle;
            assertEquals(loadedCar.parts.length, 2);
        }

        public function testCriteriaAPI():void
        {
            trace("\nTest Criteria API");
            trace("=================");
            var organisation:Organisation = new Organisation();
            organisation.name = "Atlassian";
            em.save(organisation);

            var criteria:Criteria = em.createCriteria(Organisation);
            criteria.addLikeCondition("name", "lass").addSort("name", Sort.ASC);
            var result:ArrayCollection = em.fetchCriteria(criteria);
            var loadedOrganisation:Organisation = result[0] as Organisation;
            assertEquals(loadedOrganisation.name, "Atlassian");
        }

        public function testCriteriaAPI2():void
        {
            trace("\nTest Criteria API 2");
            trace("===================");
            var contact:Contact = new Contact();
            contact.name = "Mark";
            contact.emailAddr = "mark@codec.co.nz";
            em.save(contact);

            var criteria:Criteria = em.createCriteria(Contact);
            criteria.addJunction(criteria.createAndJunction().addLikeCondition("name", "M").addLikeCondition("emailAddr", "codec")).addSort("name");

            var result:ArrayCollection = em.fetchCriteria(criteria);
            var loadedContact:Contact = result[0] as Contact;
            assertEquals(loadedContact.name, "Mark");
        }

    }
}