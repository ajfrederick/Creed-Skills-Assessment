/**
 * @name BatchUpdateAccountMaturity
 * @description Async class that helps update acocunts in batch of 200 if 
 * OpportunityHelper.cls updateAccountMaturity() recieves more than 500 accountIds
 * as well as updates all accounts when Account Maturity Tier settings change
**/
public class BatchUpdateAccountMaturity implements Database.Batchable<SOBJECT>  {

    Set<Id> accountIds{get;set;}

    public BatchUpdateAccountMaturity( Set<Id> accIds ){
        accountIds = new Set<Id>();
        accountIds.addAll( accIds );
    }

    public Database.QueryLocator start( Database.BatchableContext context ){
        // set query string for all accounts this will happen if the tiers custom setting is update from admin screen
        String query = 'SELECT Id FROM Account';

        // if there are accountIds present the add WHERE clause to query string
        // this happens if called after updates of opportunities and we target specific accounts
        if( accountIds.size() < 0 ){
            query += ' WHERE Id IN :accountIds';
        }

        return Database.getQueryLocator( query );
    }

    public void execute( Database.BatchableContext context, SObject[] accounts ){
        Set<Id> batchedIds = new Set<Id>();
 
        for( SObject account : accounts ){
            Id accountId = (Id) account.get('Id');
 
            batchedIds.add(accountId);
        }
 
         OpportunityHelper.updateAccountMaturity( batchedIds );
     }
 
     public void finish( Database.BatchableContext context ){
 
     }
}
