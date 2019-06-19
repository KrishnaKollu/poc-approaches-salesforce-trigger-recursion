@isTest
public with sharing class AccountTriggerHandlerBaseTest {
    public AccountTriggerHandlerBaseTest(ITriggerHandler accountHandler) {
        TriggerHandlers.setMockHandler(Account.SObjectType, accountHandler);
    }

    public void testTrigger_AllOrNoneUpdate_NoWorkflow()
    {
        List<Account> testAccounts = new List<Account>();
        testAccounts.add(new Account(Name='ACME', BillingStreet='Street1'));
        testAccounts.add(new Account(Name='Universal Containers'));
        insert testAccounts;

        Test.startTest();
            testAccounts[0].BillingStreet = 'Street Changed';
            testAccounts[1].BillingStreet = 'Street Set';
            update testAccounts;
        Test.stopTest();

        List<Task> resultingTasks = [Select Id, WhatId From Task Order By WhatId];
        System.assertEquals(2, resultingTasks.size(), 'When the BillingStreet field is changed on Accounts, it should result in a single Task record for each Account');
        System.assertEquals(testAccounts[0].Id, resultingTasks[0].WhatId, 'When an Account\'s BillingStreet is changed, the resulting Task record must be associated to the Account');
        System.assertEquals(testAccounts[1].Id, resultingTasks[1].WhatId, 'When an Account\'s BillingStreet is changed, the resulting Task record must be associated to the Account');
  }

    public void testTrigger_AllOrNoneUpdate_WorkflowExists()
    {
        List<Account> testAccounts = new List<Account>();
        testAccounts.add(new Account(Name='ACME', BillingStreet='Street1'));
        testAccounts.add(new Account(Name='Universal Containers'));
        insert testAccounts;

        Test.startTest();
            for(Account testAccount : testAccounts)
            {
                testAccount.BillingStreet = 'New Street Value';
                testAccount.Run_Workflow_Rule__c = true;
            }
            update testAccounts;
        Test.stopTest();

        List<Task> resultingTasks = [Select Id, WhatId From Task Order By WhatId];
        System.assertEquals(2, resultingTasks.size(), 'When the BillingStreet field is changed on Accounts, it should result in a single Task record for each Account');
        System.assertEquals(testAccounts[0].Id, resultingTasks[0].WhatId, 'When an Account\'s BillingStreet is changed, the resulting Task record must be associated to the Account');
        System.assertEquals(testAccounts[1].Id, resultingTasks[1].WhatId, 'When an Account\'s BillingStreet is changed, the resulting Task record must be associated to the Account');
    }

    public void testTrigger_PartialSuccessUpdate_NoWorkflow() {
        List<Account> testAccounts = new List<Account>();
        testAccounts.add(new Account(Name='ACME', BillingStreet='Street1'));
        testAccounts.add(new Account(Name='Universal Containers'));
        insert testAccounts;

        Test.startTest();
            testAccounts[0].BillingStreet = 'Street Changed';
            testAccounts[1].Fail_Validation_Rule__c = true;
            testAccounts[1].BillingStreet = 'Street Set';
            Database.update(testAccounts, false);
        Test.stopTest();

        List<Task> resultingTasks = [Select Id, WhatId From Task Order By WhatId];
        System.assertEquals(1, resultingTasks.size(), 'When the BillingStreet field is changed on Accounts, it should result in a single Task record for each successfully updated Account');
        System.assertEquals(testAccounts[0].Id, resultingTasks[0].WhatId, 'When an Account\'s BillingStreet is changed, the resulting Task record must be associated to the Account');
    }

    public void testTrigger_PartialSuccessUpdate_WorkflowExists()
    {
        List<Account> testAccounts = new List<Account>();
        testAccounts.add(new Account(Name='ACME', BillingStreet='Street1'));
        testAccounts.add(new Account(Name='Universal Containers'));
        insert testAccounts;

        Test.startTest();
            for(Account testAccount : testAccounts)
            {
                testAccount.BillingStreet = 'New Street Value';
                testAccount.Run_Workflow_Rule__c = true;
            }
            testAccounts[1].Fail_Validation_Rule__c = true;
            Database.update(testAccounts, false);
        Test.stopTest();

        List<Task> resultingTasks = [Select Id, WhatId From Task Order By WhatId];
        System.assertEquals(1, resultingTasks.size(), 'When the BillingStreet field is changed on Accounts, it should result in a single Task record for each successfully updated Account');
        System.assertEquals(testAccounts[0].Id, resultingTasks[0].WhatId, 'When an Account\'s BillingStreet is changed, the resulting Task record must be associated to the Account');
    }

    public void testTrigger_AllOrNoneUpdate_NoWorkflow_BulkDML()
    {
        List<Account> testAccounts = new List<Account>();
        for(Integer i = 0; i < 450; i++)
        {
            testAccounts.add(new Account(Name='ACME', BillingStreet='0'));
        }
        insert testAccounts;

        Test.startTest();
            for(Account testAccount : testAccounts)
            {
                testAccount.BillingStreet = 'Street Changed';
            }
            update testAccounts;
        Test.stopTest();

        List<AggregateResult> results = [Select WhatId, count(Id) From Task Group By WhatId Having count(id)=1];
        System.assertEquals(testAccounts.size(), results.size(), 'When the BillingStreet field is changed on Accounts, it should result in a single Task record for each Account');
    }

    public void testTrigger_AllOrNoneUpdate_WorkflowExists_BulkDML()
    {
        List<Account> testAccounts = new List<Account>();
        for(Integer i = 0; i < 450; i++)
        {
            testAccounts.add(new Account(Name='ACME', BillingStreet='0'));
        }
        insert testAccounts;

        Test.startTest();
            for(Account testAccount : testAccounts)
            {
                testAccount.BillingStreet = 'New Street Value';
                testAccount.Run_Workflow_Rule__c = true;
            }
            update testAccounts;
        Test.stopTest();

        List<AggregateResult> results = [Select WhatId, count(Id) From Task Group By WhatId Having count(id)=1];
        System.assertEquals(testAccounts.size(), results.size(), 'When the BillingStreet field is changed on Accounts, it should result in a single Task record for each Account');
    }

    public void testTrigger_PartialSuccessUpdate_NoWorkflow_BulkDML() {
        List<Account> testAccounts = new List<Account>();
        for(Integer i = 0; i < 450; i++)
        {
            testAccounts.add(new Account(Name='ACME', BillingStreet='0'));
        }
        insert testAccounts;

        Test.startTest();
            for(Account testAccount : testAccounts)
            {
                testAccount.BillingStreet = 'New Street Value';
            }
            testAccounts[0].Fail_Validation_Rule__c = true;
            Database.update(testAccounts, false);
        Test.stopTest();

        List<AggregateResult> results = [Select WhatId, count(Id) From Task Group By WhatId Having count(id)=1];
        System.assertEquals(testAccounts.size() - 1, results.size(), 'When the BillingStreet field is changed on Accounts, it should result in a single Task record for each successfully updated Account');
    }

    public void testTrigger_PartialSuccessUpdate_WorkflowExists_BulkDML()
    {
        List<Account> testAccounts = new List<Account>();
        for(Integer i = 0; i < 450; i++)
        {
            testAccounts.add(new Account(Name='ACME', BillingStreet='0'));
        }
        insert testAccounts;

        Test.startTest();
            for(Account testAccount : testAccounts)
            {
                testAccount.BillingStreet = 'New Street Value';
                testAccount.Run_Workflow_Rule__c = true;
            }
            testAccounts[449].Fail_Validation_Rule__c = true;
            Database.update(testAccounts, false);
        Test.stopTest();

        List<AggregateResult> results = [Select WhatId, count(Id) From Task Group By WhatId Having count(id)=1];
        System.assertEquals(testAccounts.size() - 1, results.size(), 'When the BillingStreet field is changed on Accounts, it should result in a single Task record for each successfully updated Account');
    }
}
