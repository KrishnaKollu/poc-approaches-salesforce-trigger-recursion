/* 
 * This trigger handler leverages limit statistics to detect when the results of a previous run of the same trigger were discarded.
 * This could occur in a database update where allOrNone=false, if there were initially some failures, and Salesforce decides to re-run
 * the trigger for a subset of records that didn't report issues.
 *
 * Salesforce documents that "During the second and third attempts, governor limits are reset to their original state 
 * before the first attempt". By capturing the state of the limits towards the end of an attempt, and then comparing those
 * to the state of the limits at the beginning of an attempt, it is possible to detect if the earlier trigger run results were discarded,
 * which means the trigger must not be blocked from running this time for any record.
 * 
 * For demonstration, this example has logic in the handler. The best practice is delegating to service methods.
 * There's also the opportunity to refactor this logic to make it more generally re-usable. 
 */
public with sharing class AccountTriggerHandler5 implements ITriggerHandler {
    private static Set<Id> recordsToSkip = new Set<Id>();
    private static RecordedLimits lastRecordedLimits;

    public void onBeforeUpdate(List<SObject> updatedRecords, Map<Id, SObject> oldRecords) {
        repairRecordsToSkip();
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

        /* Keep track of current state of limits */
        recordLimits();
    }

    private void repairRecordsToSkip()
    {
        RecordedLimits currentLimits = new RecordedLimits();
        Boolean previousTriggerRunResultsDiscarded = currentLimits.areLessThan(lastRecordedLimits);
        if(previousTriggerRunResultsDiscarded)
            recordsToSkip.clear();
    }

    private void recordLimits()
    {
        lastRecordedLimits = new RecordedLimits();
    }

    private class RecordedLimits {
        private Integer dmlRows;
        private Integer queryRows;
        private Integer cpuTime;

        private RecordedLimits(Integer dmlRows, Integer queryRows, Integer cpuTime)
        {
            this.dmlRows = dmlRows;
            this.queryRows = queryRows;
            this.cpuTime = cpuTime;
        }

        public RecordedLimits()
        {
            this(Limits.getDmlRows(), Limits.getQueryRows(), Limits.getCpuTime()); 
        }

        public Boolean areLessThan(RecordedLimits compareTo) {
            if(compareTo!=null && ((this.cpuTime < compareTo.cpuTime) || (this.dmlRows < compareTo.dmlRows) || 
                                   (this.queryRows < compareTo.queryRows)))
                return true;
            else
                return false;
        }
    }
}