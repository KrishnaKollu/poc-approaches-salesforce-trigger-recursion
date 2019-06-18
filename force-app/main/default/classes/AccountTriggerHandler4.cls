/* 
 * This trigger handler leverages a custom field on the Account object to detect when the results of a previous run of the same trigger
 * were discarded. This could occur in a database update where allOrNone=false, if there were initially some failures, and Salesforce 
 * decides to re-run the trigger for a subset of records that didn't report issues.
 *
 * The trigger produces a timestamp, and persists the same timestamp on processed records as well as a static variable. 
 * To keep it light-weight, it will use a "before update" operation to persist the timestamp in the database. 
 * Every time the trigger runs, it will check to see if the value persisted in the database is less than that in the static variable. 
 * If so, then it knows that the results of its initial run were discarded and that it should not be blocked from executing. 
 *
 * This passes tests in AccountTriggerHandler4Test, but could run into an edge case of its own if Salesforce trigger performance improves
 * and it could be realistic for a trigger's initial execution and it's re-run occuring in the same millisecond.
 * 
 * For demonstration, this example has logic in the handler. The best practice is delegating to service methods.
 * There's also the opportunity to refactor this logic to make it more generally re-usable. 
 */
public with sharing class AccountTriggerHandler4 implements ITriggerHandler {
    private static Map<Id, Long> timestampById = new Map<Id, Long>();
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
        Boolean didRollbackOccur = didRollbackOccur(updatedRecords);
        if(didRollbackOccur)
            recordsToSkip.clear();
        trackTimestamps(updatedRecords);
    }

    private Boolean didRollbackOccur(List<Account> updatedRecords)
    {
        for(Account record : updatedRecords)
        {
            if(recordsToSkip.contains(record.Id) && timestampById.containsKey(record.Id))
            {
                Long persistedTimestamp = (record.Apex_Trigger_Timestamp__c != null ? Long.valueOf(record.Apex_Trigger_Timestamp__c) : 0);
                Long lastTriggerRanTimestamp = timestampById.get(record.Id);
                Boolean rollBackOccured = persistedTimestamp < lastTriggerRanTimestamp;
                
                if(rollBackOccured)
                    return true;
            }
        }

        return false;
    }

    private void trackTimestamps(List<Account> updatedRecords)
    {
        Long nowTimestamp = System.currentTimeMillis();
        for(Account record : updatedRecords)
        {
            record.Apex_Trigger_Timestamp__c = String.valueOf(nowTimestamp);
            timestampById.put(record.Id, nowTimestamp);
        }
    }
}