@isTest
public class BatchIt_test {

    @isTest static void test_insert() {
        Account[] accounts = new Account[]{};
        for (Integer i = 0; i < 20; i++) {
            accounts.add(TestData.account('Test' + i));
        }

        Assert.areEqual(0, [SELECT COUNT() FROM Account]);

        Test.startTest();
        Database.executeBatch(new BatchIt(accounts, 'insert'));
        Test.stopTest();

        Assert.areEqual(20, [SELECT COUNT() FROM Account]);
    }

    @isTest static void test_update() {
        Account[] accounts = new Account[]{};
        for (Integer i = 0; i < 20; i++) {
            accounts.add(TestData.account('Test' + i));
        }
        insert accounts;

        for (Account account : accounts) {account.Name = account.Name.replace('Test', 'New');}

        Assert.areEqual(20, [SELECT COUNT() FROM Account]);
        Assert.areEqual(0,  [SELECT COUNT() FROM Account WHERE Name LIKE '%New%']);

        Test.startTest();
        Database.executeBatch(new BatchIt(accounts, 'update'));
        Test.stopTest();

        Assert.areEqual(20, [SELECT COUNT() FROM Account WHERE Name LIKE '%New%']);
    }

    @isTest static void test_upsert() {
        Account[] accounts = new Account[]{};
        for (Integer i = 0; i < 20; i++) {
            accounts.add(TestData.account('Test' + i));
        }
        insert accounts;

        for (Account account : accounts) {account.Name = account.Name.replace('Test', 'New');}

        for (Integer i = 0; i < 10; i++) {accounts.add(TestData.account('NewTest' + i));}

        Assert.areEqual(20, [SELECT COUNT() FROM Account]);
        Assert.areEqual(0,  [SELECT COUNT() FROM Account WHERE Name LIKE '%New%']);

        Test.startTest();
        Database.executeBatch(new BatchIt(accounts, 'upsert'));
        Test.stopTest();

        Assert.areEqual(10, [SELECT COUNT() FROM Account WHERE Name LIKE '%NewTest%']);
        Assert.areEqual(30, [SELECT COUNT() FROM Account WHERE Name LIKE '%New%']);
    }

    @isTest static void test_now() {
        Account[] accounts = new Account[]{};
        for (Integer i = 0; i < 20; i++) {
            accounts.add(TestData.account('Test' + i));
        }
        insert accounts;

        for (Account account : accounts) {account.Name = account.Name.replace('Test', 'New');}

        for (Integer i = 0; i < 10; i++) {accounts.add(TestData.account('NewTest' + i));}

        Assert.areEqual(20, [SELECT COUNT() FROM Account]);
        Assert.areEqual(0,  [SELECT COUNT() FROM Account WHERE Name LIKE '%New%']);

        Test.startTest();
        BatchIt.now(accounts);
        Test.stopTest();

        Assert.areEqual(10, [SELECT COUNT() FROM Account WHERE Name LIKE '%NewTest%']);
        Assert.areEqual(30, [SELECT COUNT() FROM Account WHERE Name LIKE '%New%']);
    }

}
