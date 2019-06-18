trigger AccountTrigger on Account (before update, after update) {
    TriggerHandlers.handle(Account.SObjectType);
} 