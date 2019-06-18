public interface ITriggerHandler {
    /* For sake of example, other methods are not included */
    void onBeforeUpdate(List<SObject> updatedRecords, Map<Id, SObject> oldRecords);
    void onAfterUpdate(List<SObject> updatedRecords, Map<Id, SObject> oldRecords);
}