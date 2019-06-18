@isTest
private class AccountTriggerHandler5Test {
    private final static AccountTriggerHandlerBaseTest baseTests;
    
    static {
        baseTests = new AccountTriggerHandlerBaseTest(new AccountTriggerHandler5());
    }

    @isTest
    public static void testTrigger_AllOrNoneUpdate_NoWorkflow()
    {
        baseTests.testTrigger_AllOrNoneUpdate_NoWorkflow();
    }

    @isTest
    public static void testTrigger_AllOrNoneUpdate_WorkflowExists()
    {
        baseTests.testTrigger_AllOrNoneUpdate_WorkflowExists();
    }

    @isTest
    public static void testTrigger_PartialSuccessUpdate_NoWorkflow() {
        baseTests.testTrigger_PartialSuccessUpdate_NoWorkflow();
    }

    @isTest
    public static void testTrigger_PartialSuccessUpdate_WorkflowExists()
    {
        baseTests.testTrigger_PartialSuccessUpdate_WorkflowExists();
    }
}