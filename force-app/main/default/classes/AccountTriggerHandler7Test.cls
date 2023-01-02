@isTest
private class AccountTriggerHandler7Test {
    private final static AccountTriggerHandlerBaseTest baseTests;
    
    static {
        baseTests = new AccountTriggerHandlerBaseTest(new AccountTriggerHandler7());
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
    
    @isTest
    public static void testTrigger_AllOrNoneUpdate_NoWorkflow_BulkDML()
    {
        baseTests.testTrigger_AllOrNoneUpdate_NoWorkflow_BulkDML();
    }

    @isTest
    public static void testTrigger_AllOrNoneUpdate_WorkflowExists_BulkDML()
    {
        baseTests.testTrigger_AllOrNoneUpdate_WorkflowExists_BulkDML();
    }

    @isTest
    public static void testTrigger_PartialSuccessUpdate_NoWorkflow_BulkDML()
    {
        baseTests.testTrigger_PartialSuccessUpdate_NoWorkflow_BulkDML();
    }

    @isTest
    public static void testTrigger_PartialSuccessUpdate_WorkflowExists_BulkDML()
    {
        baseTests.testTrigger_PartialSuccessUpdate_WorkflowExists_BulkDML();
    }
}