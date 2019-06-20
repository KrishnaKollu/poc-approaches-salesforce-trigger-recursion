# Trigger Recursion Blocking Approaches and Gotchas

**Check this out if...**

Check this out if you want to learn about "gotchas" when building "before update" or "after update" apex triggers. 

Most notably, popular recommendations to use a `static` boolean or a static `Set<Id>` to control trigger recursion have drawbacks. It could lead to the trigger not firing at all on a data load or an integration. I've proposed here alternative approaches that work with Salesforce behavior on allOrNone=false (partial success) operations - usually default behavior of a data load or integration. 

**Motivation**

The best practice when writing "before update" or "after update" apex triggers is to compare field values, and only perform specific trigger operations if values in given fields are changed.

i.e. If you want to build a trigger that creates an Order when the Opportunity is closed, you want your trigger to check to see that the Opportunity status *changed* to Closed Won from a different value.  After all, you wouldn't want any update to any Opportunity that is Closed Won to result in a new Order. You just want the update that *makes* the Opportunity "Closed Won" to result in an Order.

In an execution context, recall that triggers run first, and then workflow rules run later. If the workflow rules end up updating the same record, they will cause the same trigger to fire again in the same execution context.

There's an important platform consideration here: ([See: Order of Operations]) 

> Salesforce Documentation on *Triggers and Order of Execution*
>> Trigger.old contains a version of the objects before the specific update that fired the trigger. However, there is an exception. When a record is updated and subsequently triggers a workflow rule field update, Trigger.old in the last update trigger doesn’t contain the version of the object immediately before the workflow update, but the object before the initial update was made. For example, suppose that an existing record has a number field with an initial value of 1. A user updates this field to 10, and a workflow rule field update fires and increments it to 11. In the update trigger that fires after the workflow field update, the field value of the object obtained from Trigger.old is the original value of 1, rather than 10, as would typically be the case. 

In other words, if a workflow rule causes a trigger to run again, Trigger.old will contain the content of the record before the trigger had even run initially.

**Why this matters**

Let's say you built an "after update" Opportunity trigger that creates an Order when the Opportunity is closed. You develop the trigger to fire when `opportunity.Status = 'Closed Won' && opportunity.Status != Trigger.oldMap.get(opportunity.Id).Status`. 

Let's walk through an example. Let's say the Status of an Opportunity changes from "Pending Review" to "Closed Won". When the trigger initially runs, the above condition is true, and the trigger functionality fires (creating an Order). Opportunity workflow rules run, and let's say they change an unrelated field on the Opportunity. Now your trigger runs again. In this workflow scenario, Trigger.old isn't updated and still has the old status of "Pending Review".

This means your trigger will create a duplicate Order. That's not good.

So how do you deal with this? You can consider refactoring away from using workflow rules all together. But here's the catch... if someone builds a workflow rule in the future, or if you install a managed package that *happens* to use a workflow rule on that object, then you're back in the same boat.

**What not to do**

A popular approach to addressing this challenge is to implement a static boolean to store whether the trigger ran. If the static boolean says the trigger didn't run, then proceed with the trigger; if not, stop. 

This will work for the use case I mentioned earlier with the workflow. But it introduces another challenge.

Consider the use case where an integration sets Opportunity records to "Closed Won". There are two salient points about this integration:
* It runs in bulk. A single request might update multiple Opportunity records.
* As is standard practice, it uses allOrNone=false (the default SOAP API setting). This means if the integration tried to update 5 opportunity records, but a couple failed because of a validation rule, the others will go through.

How does allOrNone=false work when there are errors? Salesforce says "If there were errors during the first attempt, the runtime engine makes a second attempt that includes only those records that did not generate errors...triggers are re-fired on this subset of records." ([See: Bulk Dml Exception Handling])

This means that Salesforce doesn't persist the results of the original trigger run, and re-runs the trigger again, this time only including records that didn't hit validation rules. 

*Crucially, Salesforce doesn't reset static variables when this occurs.* This is not a bug. I filed a case sometime back on this behavior. It went to R&D who concluded that it was WAD (working as designed). They confirmed that "static variables are not reverted with a rollback. If a trigger is retried, the static variables in the second run will still have the values that they were initialized to in the first run. Only database values re rolled back." 

In other words, If there is a static boolean that was set to true after the trigger originally ran, it will still be true when the trigger re-executes. Here, that's a problem, because the results of the first trigger run aren't persisted to the database. This means that the static boolean has effectively caused the trigger to be skipped. That's not good.

I've replicated these limitations with the static boolean solution in this git repository. Please feel free to deploy this repo to a scratch org and see for yourself.

The project has a trigger on Account that will create a Task when the BillingStreet field changes on the Account. I've implemented a number of trigger handlers that implement the same business logic but have different instrumentations for blocking trigger recursion. 

These are handlers that re-produce common gotchas with using static variables exclusively to do recursion blocking:

* AccountTriggerHandler1.cls 
    * This has no logic to block recursion.
    * Issue: It creates duplicate records when a workflow causes the trigger to re-execute.
* AccountTriggerHandler2.cls 
    * This has logic to block recursion via a static boolean.
    * Issue #1: Trigger doesn't run when partial success operation encounters an error, and the trigger is re-executed.
    * Issue #2: When Apex executes a bulk dml update operation that exceeds the chunk size of 200 records, each chunk is sequentially processed by the trigger. However, the static boolean applies to the trigger overall, and will disable processing of additional chunks. This means only the first chunk that hits the trigger will be processed. This issue occurs regardless of the allOrNone flag, and affects large operations performed in Apex (i.e. a batch job updating a large number of records in a single DML statement).
* AccountTriggerHandler3.cls 
    * This has logic to block recursion by capturing a static set of ids (a variation of the static boolean approach that solves for the chunk processing issue). This set of ids stores records which have already been processed by the trigger, and therefore should not be processed again.
    * Issue: Trigger doesn't run when partial success operation encounters an error, and trigger is re-executed.

I've re-produced the above issues in the following unit tests. To find the corresponding test class, see `AccountTriggerHandler1Test.cls` and so on. 

Below are the test results. The numbers on the horizontal axis correspond to the trigger handler number.

||1|2|3|
|--- |--- |--- |--- |
|`testTrigger_AllOrNoneUpdate_NoWorkflow`|✔|✔|✔|
|`testTrigger_AllOrNoneUpdate_WorkflowExists`|✖|✔|✔|
|`testTrigger_AllOrNoneUpdate_NoWorkflow_BulkDML`|✔|✖|✔|
|`testTrigger_AllOrNoneUpdate_WorkflowExists_BulkDML`|✖|✖|✔|
|`testTrigger_PartialSuccessUpdate_NoWorkflow`|✔|✖|✖|
|`testTrigger_PartialSuccessUpdate_WorkflowExists`|✖|✖|✖|
|`testTrigger_PartialSuccessUpdate_NoWorkflow_BulkDML`|✔|✖|✖|
|`testTrigger_PartialSuccessUpdate_WorkflowExists_BulkDML`|✖|✖|✖|

Note, I built a very rudimentary injection layer between Account.trigger and any of its implementing handlers to allow test classes to substitute the trigger handler. 

**Alternate Approaches**

It's possible to solve for this on a case by case basis. For instance, you can check to see if the child records were created before creating them. However, that eats up governor limits, and implementing that type of logic in multiple triggers would further consume already scare resources. What I'm exploring here however are more generic solutions that don't require performing DML operations or queries.

I explored three different ideas for solving these challenges. All ideas extend on the solution in AccountTriggerHandler3.cls, but keep in mind that static variables don't get rolled back when Salesforce does error handling in a partial success operation and re-runs the trigger with a subset of records.

*AccountTriggerHandler4.cls*
* Summary
    * Trigger produces a timestamp and persists the same timestamp on processed records as well as a static variable. 
    * To keep it light-weight, it will use a "before update" operation to persist the timestamp in the database. This avoids having to do a more expensive DML operation.
    * When the trigger runs, if a record was flagged in a static set as having already been processed by this trigger, it will check to see if the timestamp persisted in the database is less than that in the static variable. If so, then it knows that the results of its initial run were discarded and that it should not be blocked from executing. 
* Pros
    * This works for all test cases in AccountTriggerHandlerBaseTest.
* Cons
    * Requires a custom field on object.
    * Since it's comparing timestamps, it will run into an issue if Salesforce trigger performance improves and it could be realistic for a trigger's initial execution and it's re-execution to occur in the same millisecond.

*AccountTriggerHandler5.cls*
* Summary
    * Background: Salesforce documents that "During the second and third attempts, governor limits are reset to their original state* before the first attempt". This handler tries to detect whether a rollback occurred based on the limits being reset.
    * Capture the state of key governor limits at the end of the "after update" portion of the trigger in a static variable.
    * At the start of the "before update" portion of the same trigger, check the state of governor limits against the previously captured state. If current consumed limits (as quantifiable by calls to the `Limits` class) are _less_ than what was previously captured in the static variable, then this implies that governor limits must have been reset, which also implies that the original results of the trigger were discarded and that the trigger should not be blocked from executing
    * In this proof of concept code, I'm looking at a few limits in particular, but it can be extended as appropriate.
* Pros
    * This works for all test cases in AccountTriggerHandlerBaseTest.
    * Doesn't require a custom field on object.
* Cons
    * This might not work if trigger execution is non-deterministic. i.e. if there are multiple triggers on the same object.

*AccountTriggerHandler6.cls*
* Summary
    * Trigger produces a unique identifier scoped to the trigger execution and persists the same value on processed records as well as a static variable. 
    * To keep it light-weight, it will use a "before update" operation to persist the same identifier in the database. This avoids having to do a more expensive DML operation.
    * When the trigger runs, if a record was flagged in a static set as having already been processed by this trigger, it will then check to see if the identifier persisted in the database is different from that in the static variable. If so, then it knows that the results of its initial run were discarded and that it should not be blocked from executing.
* Pros
    * This works for all test cases in AccountTriggerHandlerBaseTest.
* Cons
    * Requires a custom field on object.

Of the above approaches, I favor AccountTriggerHandler6.cls.

**Last Words**

My main motivation with this repo is to draw attention to the lifetime of a static variable in a partial success operation and how that influences trigger design. In a nutshell, leveraging just static variables to manage trigger recursion is unsafe and could result in your trigger not firing consistently.

Please keep in mind that this public repo is strictly proof of concept code and is not production-ready as-is. For instance, the recursion handling specific code needs to refactored to be reusable across multiple triggers and trigger events and not as coupled to the business logic. 

Please feel free to reach out and share suggestions/thoughts/concerns. 

[See: Order of Operations]:https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_triggers_order_of_execution.htm
[See: Bulk Dml Exception Handling]:https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_dml_bulk_exceptions.htm
