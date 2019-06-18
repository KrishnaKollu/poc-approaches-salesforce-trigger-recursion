public with sharing class TriggerHandlers {
    private static Map<SObjectType, ITriggerHandler> handlerByType = new Map<SObjectType, ITriggerHandler> {
        Account.SObjectType => (new AccountTriggerHandler5())
    };

    public static void setMockHandler(SObjectType objectType, ITriggerHandler handler)
    {
        handlerByType.put(objectType, handler);
    }

    public static void handle(SObjectType objectType) {
        ITriggerHandler handler = handlerByType.get(objectType);
        if(handler==null)
            return;

        if(Trigger.isUpdate)
        {
            if(Trigger.isBefore)
            {
                handler.onBeforeUpdate(Trigger.new, Trigger.oldMap);
            }
            else if(Trigger.isAfter)
            {
                handler.onAfterUpdate(Trigger.new, Trigger.oldMap);
            }
        }
    }
}
