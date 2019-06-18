/* 
 * This trigger handler uses a static set of ids to detect when a trigger has already run for a particular record,
 * and does not run the trigger for those records.
 * 
 * For demonstration, this example has logic in the handler. The best practice is delegating to service methods. 
 */
public with sharing class AccountTriggerHandler3 implements ITriggerHandler {
    private static Set<Id> recordsToSkip = new Set<Id>();

    public void onBeforeUpdate(List<SObject> updatedRecords, Map<Id, SObject> oldRecords) {}

    public void onAfterUpdate(List<SObject> updatedRecords, Map<Id, SObject> oldRecords) {
        /* Identify accounts needing tasks */
        List<Account> accountsWithStreetChange = new List<Account>();
        for(Account newAccount : (List<Account>) updatedRecords)
        {
            Account oldAccount = (Account) (oldRecords.get(newAccount.Id));
            if(!recordsToSkip.contains(newAccount.Id) && newAccount.BillingStreet != oldAccount.BillingStreet)
            {
                accountsWithStreetChange.add(newAccount);
                recordsToSkip.add(newAccount.Id);
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