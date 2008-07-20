package ormtest
{
    import flexunit.framework.TestCase;
    import flexunit.framework.TestSuite;

    import mx.collections.ArrayCollection;
    import mx.collections.IList;
    import mx.rpc.Responder;

    import nz.co.codec.flexorm.EntityError;
    import nz.co.codec.flexorm.EntityEvent;
    import nz.co.codec.flexorm.EntityManagerAsync;

    import ormtest.model.Contact;
    import ormtest.model.Lesson;
    import ormtest.model.Order;
    import ormtest.model.Organisation;
    import ormtest.model.Resource;
    import ormtest.model.Role;
    import ormtest.model.Schedule;
    import ormtest.model.Student;
    import ormtest.model2.Person;

    public class EntityManagerAsyncTest extends TestCase
    {
        private static var em:EntityManagerAsync = EntityManagerAsync.instance;

        public static function suite():TestSuite
        {
            em.debugLevel = 1;
            var ts:TestSuite = new TestSuite();
            ts.addTest(new EntityManagerAsyncTest("testNullFindAll"));
            ts.addTest(new EntityManagerAsyncTest("testSaveSimpleObject"));
            ts.addTest(new EntityManagerAsyncTest("testFindAll"));
            ts.addTest(new EntityManagerAsyncTest("testGraphFindAll"));
            ts.addTest(new EntityManagerAsyncTest("testSaveManyToOneAssociation"));
            ts.addTest(new EntityManagerAsyncTest("testSaveOneToManyAssociations"));
            ts.addTest(new EntityManagerAsyncTest("testSaveManyToManyAssociation"));
            ts.addTest(new EntityManagerAsyncTest("testDelete"));
            ts.addTest(new EntityManagerAsyncTest("testCascadeSaveUpdate"));
            ts.addTest(new EntityManagerAsyncTest("testInheritance1"));
            ts.addTest(new EntityManagerAsyncTest("testInheritance2"));
            ts.addTest(new EntityManagerAsyncTest("testTransaction"));
            ts.addTest(new EntityManagerAsyncTest("testCompositeKey"));
            ts.addTest(new EntityManagerAsyncTest("testCompositeKeyOneToMany"));
            ts.addTest(new EntityManagerAsyncTest("testAlternateAPI"));
            ts.addTest(new EntityManagerAsyncTest("testOneToManyIndexedCollection"));
            ts.addTest(new EntityManagerAsyncTest("testManyToManyIndexedCollection"));
            return ts;
        }

        public function EntityManagerAsyncTest(methodName:String=null)
        {
            super(methodName);
        }

        public function testNullFindAll():void
        {
            trace("\nTest Null Find All");
            trace("==================");
            em.findAll(Organisation, new Responder(
                addAsync(function(event:EntityEvent):void
                {
                    trace("findAll fired...");
                    assertNull(event.data);
                }, 1500),

                function(error:EntityError):void
                {
                    trace("Failed in select: " + error.message);
                    trace(error.getStackTrace());
                }
            ));
        }

        public function testSaveSimpleObject():void
        {
            trace("\nTest Save Simple Object");
            trace("=======================");
            var organisation:Organisation = new Organisation();
            organisation.name = "Codec Software Limited";
            em.save(organisation, new Responder(
                addAsync(function(event:EntityEvent):void
                {
                    trace("save fired...");
                    em.load(Organisation, Organisation(event.data).id, new Responder(
                        addAsync(function(event:EntityEvent):void
                        {
                            trace("load fired...");
                            assertEquals(event.data.name, "Codec Software Limited");
                        }, 1500),

                        function(error:EntityError):void
                        {
                            trace("Failed in load: " + error.message);
                            trace(error.getStackTrace());
                        }
                    ));
                }, 1500),

                function(error:EntityError):void
                {
                    trace("Failed in save: " + error.message);
                    trace(error.getStackTrace());
                }
            ));
        }

        public function testFindAll():void
        {
            trace("\nTest Find All");
            trace("=============");
            var organisation:Organisation = new Organisation();
            organisation.name = "Adobe";
            em.save(organisation, new Responder(
                addAsync(function(event:EntityEvent):void
                {
                    trace("save fired...");
                    em.findAll(Organisation, new Responder(
                        addAsync(function(event:EntityEvent):void
                        {
                            trace("findAll fired...");
                            assertEquals(event.data.length, 2);
                        }, 1500),

                        function(error:EntityError):void
                        {
                            trace("Failed in select: " + error.message);
                            trace(error.getStackTrace());
                        }
                    ));
                }, 1500),

                function(error:EntityError):void
                {
                    trace("Failed in save: " + error.message);
                    trace(error.getStackTrace());
                }
            ));
        }

        public function testGraphFindAll():void
        {
            trace("\nTest Graph Find All");
            trace("===================");
            var james:Contact = new Contact();
            james.name = "James";
            var jamesOrders:ArrayCollection = new ArrayCollection();
            var couch:Order = new Order();
            couch.item = "Couch";
            jamesOrders.addItem(couch);
            var desk:Order = new Order();
            desk.item = "Desk";
            jamesOrders.addItem(desk);
            james.orders = jamesOrders;
            em.save(james, new Responder(
                addAsync(function(event:EntityEvent):void
                {
                    trace("save james fired...");
                    var john:Contact = new Contact();
                    john.name = "John";
                    var johnRoles:ArrayCollection = new ArrayCollection();
                    var developer:Role = new Role();
                    developer.name = "Developer";
                    johnRoles.addItem(developer);
                    var tester:Role = new Role();
                    tester.name = "Tester";
                    johnRoles.addItem(tester);
                    john.roles = johnRoles;
                    em.save(john, new Responder(
                        addAsync(function(event:EntityEvent):void
                        {
                            trace("save john fired...");
                            em.findAll(Contact, new Responder(
                                addAsync(function(event:EntityEvent):void
                                {
                                    trace("findAll fired...");
                                    assertEquals(event.data.length, 2);
                                }, 1500),

                                function(error:EntityError):void
                                {
                                    trace("Failed in select: " + error.message);
                                    trace(error.getStackTrace());
                                }
                            ));
                        }, 1500),

                        function(error:EntityError):void
                        {
                            trace(error);
                        }

                    ));
                }, 1500),

                function(error:EntityError):void
                {
                    trace("Failed in save: " + error.message);
                    trace(error.getStackTrace());
                }
            ));
        }

        public function testSaveManyToOneAssociation():void
        {
            trace("\nTest Save Many To One Association");
            trace("=================================");
            var organisation:Organisation = new Organisation();
            organisation.name = "Apple";
            // since Organisation has cascade="none" on Contact
            em.save(organisation, new Responder(
                addAsync(function(event:EntityEvent):void
                {
                    trace("save Organisation fired...");
                    var contact:Contact = new Contact();
                    contact.name = "Steve";
                    contact.organisation = event.data as Organisation;
                    em.save(contact, new Responder(
                        addAsync(function(event:EntityEvent):void
                        {
                            trace("save Contact fired...");
                            em.load(Contact, Contact(event.data).id, new Responder(
                                addAsync(function(event:EntityEvent):void
                                {
                                    trace("load fired...");
                                    var loadedContact:Contact = event.data as Contact;
                                    assertNotNull(loadedContact);
                                    assertNotNull(loadedContact.organisation);
                                    assertEquals(loadedContact.organisation.name, "Apple");
                                }, 1500),

                                function(error:EntityError):void
                                {
                                    trace("Failed in load: " + error);
                                    trace(error.getStackTrace());
                                }
                            ));
                        }, 1500),

                        function(error:EntityError):void
                        {
                            trace("Failed in save Contact: " + error);
                            trace(error.getStackTrace());
                        }
                    ));
                }, 1500),

                function(error:EntityError):void
                {
                    trace("Failed in save Organisation: " + error);
                    trace(error.getStackTrace());
                }
            ));
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
            em.save(contact, new Responder(
                addAsync(function(event:EntityEvent):void
                {
                    trace("save fired...");
                    em.load(Contact, event.data.id, new Responder(
                        addAsync(function(event:EntityEvent):void
                        {
                            trace("load fired...");
                            var loadedContact:Contact = event.data as Contact;
                            assertEquals(loadedContact.orders.length, 2);
                        }, 1500),

                        function(error:EntityError):void
                        {
                            trace("Failed in load: " + error);
                            trace(error.getStackTrace());
                        }
                    ));
                }, 1500),

                function(error:EntityError):void
                {
                    trace("Failed in save: " + error);
                    trace(error.getStackTrace());
                }
            ));
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
            em.save(contact, new Responder(
                function(event:EntityEvent):void
                {
                    em.load(Contact, Contact(event.data).id, new Responder(
                        function(event:EntityEvent):void
                        {
                            var loadedContact:Contact = event.data as Contact;
                            assertEquals(loadedContact.roles.length, 2);
                        },

                        function(error:EntityError):void
                        {
                            throw error;
                        }
                    ));
                },

                function(error:EntityError):void
                {
                    throw error;
                }
            ));
        }

        public function testDelete():void
        {
            trace("\nTest Delete");
            trace("===========");
            var organisation:Organisation = new Organisation();
            organisation.name = "Datacom";
            em.save(organisation, new Responder(
                function(event:EntityEvent):void
                {
                    em.remove(event.data as Organisation, new Responder(
                        function(event:EntityEvent):void
                        {
                            em.load(Organisation, organisation.id, new Responder(
                                function(event:EntityEvent):void
                                {
                                    assertNull(event.data);
                                },

                                function(error:EntityError):void
                                {
                                    assertNotNull(error);
                                }
                            ));
                        },

                        function(error:EntityError):void
                        {
                            throw error;
                        }
                    ));
                },

                function(error:EntityError):void
                {
                    throw error;
                }
            ));
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
            em.save(contact, new Responder(
                function(event:EntityEvent):void
                {
                    var savedContact:Contact = event.data as Contact;
                    var orderId:int = savedContact.orders[0].id;

                    // verify that cascade save-update works
                    assertTrue(orderId > 0);

                    em.remove(contact, new Responder(
                        function(event:EntityEvent):void
                        {
                            // verify that cascade delete is not in effect

                            // !!! Yes, but foreign key constraint violation is
                            // so FK constraint has been switched off using constrain="false"
                            em.load(Order, orderId, new Responder(
                                function(event:EntityEvent):void
                                {
                                    var loadedOrder:Order = event.data as Order;
                                    assertEquals(loadedOrder.item, "BMW");
                                },

                                function(error:EntityError):void
                                {
                                    throw error;
                                }
                            ));
                        },

                        function(error:EntityError):void
                        {
                            throw error;
                        }
                    ));
                },

                function(error:EntityError):void
                {
                    throw error;
                }
            ));
        }

        public function testInheritance1():void
        {
            trace("\nTest Inheritance 1");
            trace("==================");
            var person:Person = new Person();
            person.emailAddr = "person@acme.com";
            em.save(person, new Responder(
                function(event:EntityEvent):void
                {
                    em.load(Person, Person(event.data).id, new Responder(
                        function(event:EntityEvent):void
                        {
                            var loadedPerson:Person = event.data as Person;
                            assertEquals(loadedPerson.emailAddr, "person@acme.com");
                        },

                        function(error:EntityError):void
                        {
                            throw error;
                        }
                    ));
                },

                function(error:EntityError):void
                {
                    throw error;
                }
            ));
        }

        public function testInheritance2():void
        {
            trace("\nTest Inheritance 2");
            trace("==================");
            var contact:Contact = new Contact();
            contact.name = "Bill";
            contact.emailAddr = "bill@ms.com";
            em.save(contact, new Responder(
                function(event:EntityEvent):void
                {
                    em.load(Contact, Contact(event.data).id, new Responder(
                        function(event:EntityEvent):void
                        {
                            var loadedContact:Contact = event.data as Contact;
                            assertEquals(loadedContact.emailAddr, "bill@ms.com");
                        },

                        function(error:EntityError):void
                        {
                            throw error;
                        }
                    ));
                    em.load(Person, Person(event.data).id, new Responder(
                        function(event:EntityEvent):void
                        {
                            var loadedPerson:Person = event.data as Person;
                            assertEquals(loadedPerson.emailAddr, "bill@ms.com");
                        },

                        function(error:EntityError):void
                        {
                            throw error;
                        }
                    ));
                },

                function(error:EntityError):void
                {
                    throw error;
                }
            ));
        }

        public function testTransaction():void
        {
            trace("\nTest Transactions");
            trace("=================");
            var organisation:Organisation = new Organisation();
            organisation.name = "Google";
            em.save(organisation, new Responder(
                function(event:EntityEvent):void
                {
                    var contact:Contact = new Contact();
                    contact.name = "Sergey";
                    contact.organisation = organisation;
                    em.save(contact, new Responder(
                        function(event:EntityEvent):void
                        {
                            em.startTransaction(new Responder(
                                function(event:EntityEvent):void
                                {
                                    trace("successful transaction start");
                                    em.remove(organisation, new Responder(
                                        function(event:EntityEvent):void
                                        {
                                            em.endTransaction(new Responder(
                                                function(event:EntityEvent):void
                                                {
                                                    trace("transaction commit successful?");
                                                },

                                                function(error:EntityError):void
                                                {
                                                    trace("transaction commit failed: " + error);

                                                    // The transaction is expected to fail with a
                                                    // foreign key constraint violation
                                                    assertNotNull(error);
                                                }
                                            ));
                                        },

                                        function(error:EntityError):void
                                        {
                                            // TODO the remove operation is failing and responding
                                            // before commit is called.
                                            // Need to check in the sqlConnection is staying in
                                            // transaction.

                                            trace("remove operation failed: " + error);
                                        }
                                    ));
                                },

                                function(error:EntityError):void
                                {
                                    trace("transaction start failed: " + error);
                                }
                            ));
                        },

                        function(error:EntityError):void
                        {
                            trace("save operation failed");
                        }
                    ));

                },

                function(error:EntityError):void
                {
                    throw error;
                }
            ));
        }

/* not sure if the alt API makes sense for Async mode
        public function testAlternateAPI():void
        {
            em.makePersistent(Organisation);

            var organisation:Organisation = new Organisation();
            organisation.name = "Datacom";
            organisation.save();

            var loadedOrganisation:Organisation = em.loadItem(Organisation, organisation.id) as Organisation;
            assertEquals(loadedOrganisation.name, "Datacom");
        }
*/

        public function testCompositeKey():void
        {
            trace("\nTest Composite Key");
            trace("==================");
            var student:Student = new Student();
            student.name = "Mark";
            em.save(student, new Responder(
                function(event:EntityEvent):void
                {
                    var stud:Student = event.data as Student;
                    trace("saved Student: " + stud.id + " " + stud.name);
                    var lesson:Lesson = new Lesson();
                    lesson.name = "Piano";
                    em.save(lesson, new Responder(
                        function(event:EntityEvent):void
                        {
                            var schedule:Schedule = new Schedule();
                            schedule.student = stud;
                            schedule.lesson = event.data as Lesson;
                            trace("saved Lesson: " + schedule.lesson.id + " " + schedule.lesson.name);
                            var today:Date = new Date();
                            schedule.lessonDate = today;
                            em.save(schedule, new Responder(
                                function(event:EntityEvent):void
                                {
                                    var sched:Schedule = event.data as Schedule;
                                    trace("saved Schedule: " + sched.lessonDate);
                                    em.loadItemByCompositeKey(Schedule, [sched.student, sched.lesson], new Responder(
                                        function(event:EntityEvent):void
                                        {
                                            var loadedSchedule:Schedule = event.data as Schedule;
                                            trace("loaded Schedule: " + loadedSchedule.lessonDate);
                                            assertEquals(loadedSchedule.lessonDate.fullYear, today.fullYear);
                                            assertEquals(loadedSchedule.lessonDate.month, today.month);
                                            assertEquals(loadedSchedule.lessonDate.date, today.date);
                                        },
                                        function(error:EntityError):void
                                        {
                                            throw error;
                                        }
                                    ));
                                },
                                function(error:EntityError):void
                                {
                                    throw error;
                                }
                            ));
                        },
                        function(error:EntityError):void
                        {
                            throw error;
                        }
                    ));
                },
                function(error:EntityError):void
                {
                    throw error;
                }
            ));
        }

        public function testCompositeKeyOneToMany():void
        {
            trace("\nTest Composite Key with One-to-many");
            trace("===================================");
            var student:Student = new Student();
            student.name = "Shannon";
            em.save(student, new Responder(
                function(event:EntityEvent):void
                {
                    var stud:Student = event.data as Student;
                    trace("saved Student: " + stud.id + " " + stud.name);
                    var lesson:Lesson = new Lesson();
                    lesson.name = "Viola";
                    em.save(lesson, new Responder(
                        function(event:EntityEvent):void
                        {
                            var schedule:Schedule = new Schedule();
                            schedule.student = stud;
                            schedule.lesson = event.data as Lesson;
                            trace("saved Lesson: " + schedule.lesson.id + " " + schedule.lesson.name);
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

                            em.save(schedule, new Responder(
                                function(event:EntityEvent):void
                                {
                                    var sched:Schedule = event.data as Schedule;
                                    trace("saved Schedule: " + sched.lessonDate);
                                    em.loadItemByCompositeKey(Schedule, [sched.student, sched.lesson], new Responder(
                                        function(event:EntityEvent):void
                                        {
                                            var loadedSchedule:Schedule = event.data as Schedule;
                                            trace("loaded Schedule: " + loadedSchedule.lessonDate);
                                            assertEquals(loadedSchedule.resources.length, 2);
                                        },
                                        function(error:EntityError):void
                                        {
                                            throw error;
                                        }
                                    ));
                                },
                                function(error:EntityError):void
                                {
                                    throw error;
                                }
                            ));
                        },
                        function(error:EntityError):void
                        {
                            throw error;
                        }
                    ));
                },
                function(error:EntityError):void
                {
                    throw error;
                }
            ));
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
            em.save(contact, new Responder(
                function(event:EntityEvent):void
                {
                    trace("saved contact");
                    em.load(Contact, event.data.id, new Responder(
                        function(event:EntityEvent):void
                        {
                            trace("loaded contact");
                            var loadedContact:Contact = event.data as Contact;
                            assertEquals(loadedContact.orders[1].item, "iPhone");

                            var ordersList:IList = loadedContact.orders;
                            ordersList.addItemAt(ordersList.removeItemAt(1), 0);
                            em.save(loadedContact, new Responder(
                                function(event:EntityEvent):void
                                {
                                    trace("saved contact with reordered orders collection");
                                    em.load(Contact, contact.id, new Responder(
                                        function(event:EntityEvent):void
                                        {
                                            trace("reloaded contact");
                                            var reloadedContact:Contact = event.data as Contact;
                                            assertEquals(reloadedContact.orders[1].item, "Macbook");
                                        },
                                        function(error:EntityError):void
                                        {
                                            throw error;
                                        }
                                    ));
                                },
                                function(error:EntityError):void
                                {
                                    throw error;
                                }
                            ));
                        },
                        function(error:EntityError):void
                        {
                            throw error;
                        }
                    ));
                },
                function(error:EntityError):void
                {
                    throw error;
                }
            ));
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
            em.save(contact, new Responder(
                function(event:EntityEvent):void
                {
                    trace("saved contact");
                    em.load(Contact, event.data.id, new Responder(
                        function(event:EntityEvent):void
                        {
                            trace("loaded contact");
                            var loadedContact:Contact = event.data as Contact;
                            assertEquals(loadedContact.roles[1].name, "Sparky");

                            var roleList:IList = loadedContact.roles;
                            roleList.addItemAt(roleList.removeItemAt(1), 0);
                            em.save(loadedContact, new Responder(
                                function(event:EntityEvent):void
                                {
                                    trace("saved contact with reordered roles collection");
                                    em.load(Contact, event.data.id, new Responder(
                                        function(event:EntityEvent):void
                                        {
                                            var reloadedContact:Contact = event.data as Contact;
                                            trace("reloaded contact");
                                            assertEquals(reloadedContact.roles[1].name, "Carpenter");
                                        },
                                        function(error:EntityError):void
                                        {
                                            throw error;
                                        }
                                    ));
                                },
                                function(error:EntityError):void
                                {
                                    throw error;
                                }
                            ));
                        },
                        function(error:EntityError):void
                        {
                            throw error;
                        }
                    ));
                },
                function(error:EntityError):void
                {
                    throw error;
                }
            ));
        }

    }
}