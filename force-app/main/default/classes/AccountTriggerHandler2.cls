/* 
 * This trigger handler uses a static boolean to detect when a trigger has already run, and blocks 
 * trigger re-execution based exclusively on that.
 * 
 * For demonstration, this example has logic in the handler. The best practice is delegating to service methods. 
 */
public with sharing class AccountTriggerHandler2 implements ITriggerHandler {
    private static Boolean ranAlready = false;

    public void onBeforeUpdate(List<SObject> updatedRecords, Map<Id, SObject> oldRecords) {}

    public void onAfterUpdate(List<SObject> updatedRecords, Map<Id, SObject> oldRecords) {
        if(ranAlready)
            return;

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

        ranAlready = true;
    }
}