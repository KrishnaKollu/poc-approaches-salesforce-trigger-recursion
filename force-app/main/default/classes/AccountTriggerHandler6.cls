/* 
 * This trigger handler leverages a custom field on the Account object to detect when the results of a previous run of the same trigger
 * were discarded. This could occur in a database update where allOrNone=false, if there were initially some failures, and Salesforce 
 * decides to re-run the trigger for a subset of records that didn't report issues.
 *
 * This trigger handler creates a unique identifier scoped to the trigger execution, and persists that value on processed records as well as a 
 * static variable. To keep it light-weight, it will use a "before update" operation to persist that identifier in the database. 
 * When the trigger runs, if a record was flagged in a static set as having already been processed by this trigger, it will then check 
 * to see if the identifier persisted in the database is different from that in the static variable. If so, then it knows that the results 
 * of its initial run were discarded and that it should not be blocked from executing.
 *
 * For demonstration, this example has logic in the handler. The best practice is delegating to service methods.
 * There's also the opportunity to refactor this logic to make it more generally re-usable. 
 */
public with sharing class AccountTriggerHandler6 implements ITriggerHandler {
    private static Set<Id> recordsToSkip = new Set<Id>();
    private static String triggerContextId;

    public AccountTriggerHandler6()
    {
        newTriggerContextId();
    }

    public void onBeforeUpdate(List<SObject> updatedRecords, Map<Id, SObject> oldRecords) {
        repairRecordsToSkip((List<Account>) updatedRecords);
    }

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

    private void repairRecordsToSkip(List<Account> updatedRecords)
    {
        Boolean previousTriggerRunResultsDiscarded = didRollbackOccur(updatedRecords);
        if(previousTriggerRunResultsDiscarded) {
            recordsToSkip.clear();
            newTriggerContextId();
        }
        persistTriggerContextId(updatedRecords);
    }

    private Boolean didRollbackOccur(List<Account> updatedRecords)
    {
        for(Account record : updatedRecords)
        {
            if(recordsToSkip.contains(record.Id) && record.Apex_Trigger_Context_Id__c == triggerContextId)
            {
                return false;
            }
        }
        return true;
    }
    
    private void newTriggerContextId()
    {
        Blob aes = Crypto.generateAesKey(256);
	    String hex = EncodingUtil.convertToHex(aes);
        triggerContextId = System.currentTimeMillis()+'-'+hex;
    }

    private void persistTriggerContextId(List<Account> records)
    {
        for(Account record : records)
        {
            record.Apex_Trigger_Context_Id__c = triggerContextId;
        }
    }
}