/* 
 * This trigger handler has no logic to block the trigger from running a second time in the same execution context.
 * 
 * For demonstration, this example has logic in the handler. The best practice is delegating to service methods. 
 */
public with sharing class AccountTriggerHandler1 implements ITriggerHandler {
    public void onBeforeUpdate(List<SObject> updatedRecords, Map<Id, SObject> oldRecords) {}

    public void onAfterUpdate(List<SObject> updatedRecords, Map<Id, SObject> oldRecords) {
        /* Identify accounts needing tasks */
        List<Account> accountsWithStreetChange = new List<Account>();
        for(Account newAccount : (List<Account>) updatedRecords)
        {
            Account oldAccount = (Account) (oldRecords.get(newAccount.Id));
            if(newAccount.BillingStreet != oldAccount.BillingStreet)
            {
                accountsWithStreetChange.add(newAccount);
            }
        }

        /* Create the respective tasks */
        List<Task> newTasks = new List<Task>();
        for(Account account : accountsWithStreetChange)
        {
            newTasks.add(new Task(WhatId=account.Id, Subject='Test'));
        }
        insert newTasks;
    }
}
