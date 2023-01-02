/* 
 * This trigger handler leverages the Request apex class
 *
 * For demonstration, this example has logic in the handler. The best practice is delegating to service methods.
 * There's also the opportunity to refactor this logic to make it more generally re-usable. 
 */
public with sharing class AccountTriggerHandler7 implements ITriggerHandler {
    private static Set<Id> recordsToSkip = new Set<Id>();

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
        }
        persistTriggerContextId(updatedRecords);
    }

    private Boolean didRollbackOccur(List<Account> updatedRecords)
    {
        String requestId = Request.getCurrent().getRequestId();
        for(Account record : updatedRecords)
        {
            if(recordsToSkip.contains(record.Id) && record.Apex_Trigger_Context_Id__c == requestId)
            {
                return false;
            }
        }
        return true;
    }

    private void persistTriggerContextId(List<Account> records)
    {
        String requestId = Request.getCurrent().getRequestId();
        for(Account record : records)
        {
            record.Apex_Trigger_Context_Id__c = requestId;
        }
    }
}