/**
 * @name OpportunityHelper
 * @description Helper class for Opportunity Trigger
**/
public class OpportunityHelper {
    
/**
 * TIGGER METHODS
**/

     /**
     * @name afterInsert
     * @description called by OpportunityTrigger after insert
     * @param Opportunity[] newList
    **/
    public static void afterInsert( Opportunity[] newList ){
        Set<Id> accountIds = OpportunityHelper.getAccountIds( newList );

        OpportunityHelper.updateAccountMaturity( accountIds );
    }

    /**
     * @name afterUpdate
     * @description called by OpportunityTrigger after update
     * @param Map<Id, Opportunity> oldMap
     * @param Map<Id, Opportunity> newMap
    **/
    public static void afterUpdate( Map<Id, Opportunity> oldMap, Map<Id, Opportunity> newMap ){
        Set<Id> accountIds = OpportunityHelper.getAccountIdsFromMap( oldMap, newMap );

        OpportunityHelper.updateAccountMaturity( accountIds );
    }

    /**
     * @name afterDelete
     * @description called by OpportunityTrigger after delete
     * @param Opportunity[] oldList
     * @param Opportunity[] newList
    **/
    public static void afterDelete( Opportunity[] oldList, Opportunity[] newList ){
        Set<Id> accountIds = OpportunityHelper.getAccountIds( oldList );

        OpportunityHelper.updateAccountMaturity( accountIds );
    }

    /**
     * @name afterUndelete
     * @description called by OpportunityTrigger after undelete
     * @param Opportunity[] oldList
     * @param Opportunity[] newList
    **/
    public static void afterUndelete( Opportunity[] oldList, Opportunity[] newList ){
        Set<Id> accountIds = OpportunityHelper.getAccountIds( newList );

        OpportunityHelper.updateAccountMaturity( accountIds );
    }

/**
 * BUSINESS LOGIC METHODS
**/

    /**
     * @name updateAccountMaturity
     * @description updates the associated accounts Maturity__c field
     * @param Set<Id> accountIds
    **/
    public static void updateAccountMaturity( Set<Id> accountIds ){
        // if there are no accounts to update we good
        if( accountIds.size() == 0 ) return;

        // get the tier counts from custom settings
        Account_Maturity_Tier__c[] tiers = AccountMaturityTiers.getTiers();

        // if there are more then 500 accounts then let's start a batch request to easily avoid limits on processing resources
        if( accountIds.size() > 500 ){
            BatchUpdateAccountMaturity batch = new BatchUpdateAccountMaturity( accountIds );
            
            Database.executeBatch( batch );

            return;
        }

        // use AggregateResult to get Opportunity count
        AggregateResult[] results = [SELECT
            AccountId,
            COUNT(Id) total
                FROM Opportunity
                WHERE AccountId IN :accountIds
                AND isClosed = true
                AND isWon = true
                AND isDeleted = false
                GROUP BY AccountId];

        
        Map<Id, Integer> oppTotalByAccountId = new Map<Id, Integer>();

        // loop through results and place in map to reference below when looping through accounts
        for( AggregateResult result : results ){
            oppTotalByAccountId.put( (Id) result.get('AccountId'), (Integer) result.get('total') );
        }

        // query for accounts
        Account[] accounts = [SELECT
            Id,
            Maturity__c,
            Number_of_Won_Opportunities__c
                FROM Account
                WHERE Id IN :accountIds
                AND isDeleted = false
                LIMIT 500];

        Account[] accountsToUpdate = new Account[]{};

        // loop through accounts and then through the admin created tiers 
        for( Account acc : accounts ){

            // if the Id is in the total won opp map then get the value other wise opps where deleted to 0
            if( oppTotalByAccountId.containsKey(acc.Id) )
                acc.Number_of_Won_Opportunities__c = oppTotalByAccountId.get(acc.Id);
            else {
                acc.Number_of_Won_Opportunities__c = 0;
            }
            
            for( Integer i = 0; i < tiers.size(); i++ ){
                // get reference to the current tier and the next for a tire count 'window' for comparison
                Account_Maturity_Tier__c curTier = tiers[i];
                Account_Maturity_Tier__c nextTier;

                // if it's not the last tier then assign next tier
                if( i < tiers.size()-1 ){
                    nextTier = tiers[i+1];
                }

                if( OpportunityHelper.accountTierChanged( acc, curTier, nextTier ) ){
                    acc.Maturity__c = curTier.Label__c;
                }
            }

            accountsToUpdate.add(acc);
        }

        try {
            update accountsToUpdate;
        } catch( Exception e ){
            // TO DO: handle error 
        }
    }

/**
 * UTILIY METHODS
**/

    /**
     * @name getAccountIds
     * @description utility method for getting accountIds from list of opps
     * @param Opportunity[] opps
     * @return {Set<Id>} - ids of all accounts that pass logic
    **/
    public static Set<Id> getAccountIds( Opportunity[] opps ){
        // instantiate new set to store account Ids for query
        Set<Id> accountIds = new Set<Id>();

        // loop through opps and harvest account Ids only if Closed Date is not null and Probability is 100% which indicates a 'closed won' deal
        for( Opportunity opp : opps ){
            if( OpportunityHelper.isClosedWon(opp) ){
                accountIds.add(opp.AccountId);
            }
        }

        return accountIds;
    }

    /**
     * @name getAccountIdsFromMap
     * @description utility method for getting accountIds from a map of opps. This is specifically for an update call
     * checks what types of changes may have occured and harvest accountId as necessary 
     * @param Map<Id, Opportunity> oldMap
     * @param Map<Id, Opportunity> newMap
     * @return {Set<Id>} - ids of all accounts that pass logic
    **/
    public static Set<Id> getAccountIdsFromMap( Map<Id, Opportunity> oldMap, Map<Id, Opportunity> newMap ){
        // instantiate new set to store account Ids for query
        Set<Id> accountIds = new Set<Id>();

        // loop through oldMap keyset of Opportunity Ids
        for( Id oppId : oldMap.keySet() ){
            Opportunity oldOpp = oldMap.get(oppId);
            Opportunity newOpp = newMap.get(oppId);

            // if the new opp is closed and the old is not than it's newly closed won or vice versa it was a closed won. let's update account 
            if( OpportunityHelper.oppStageMeaningfullyChanged(oldOpp, newOpp) ){
                accountIds.add( oldOpp.AccountId );
            } else
            // if there's a closed won opp and the account was changed
            if( OpportunityHelper.isClosedWon(oldOpp) && oldOpp.AccountId != newOpp.AccountId ){
                accountIds.add(oldOpp.AccountId);
                accountIds.add(newOpp.AccountId);
            }
        }

        return accountIds;
    }

    /**
     * @name isClosedWon
     * @description checks if opp ClosedDate is not null and a calculated probabilty of 100% signaling a closed won opp
     * @param Opportunity opp
     * @return {boolean} 
    **/
    public static Boolean isClosedWon( Opportunity opp ){
        return opp.IsClosed && opp.IsWon;
    }

    /**
     * @name oppStageChanged
     * @description checks if opp stage either was open and now is closed or was closed and now is open
     * @param Opportunity oldOpp
     * @param Opportunity newOpp
     * @return {boolean} 
    **/
    public static Boolean oppStageMeaningfullyChanged( Opportunity oldOpp, Opportunity newOpp ){
        return (OpportunityHelper.isClosedWon(oldOpp) && !OpportunityHelper.isClosedWon(newOpp)) || (!OpportunityHelper.isClosedWon(oldOpp) && OpportunityHelper.isClosedWon(newOpp));
    }

    /**
     * @name accountTierChanged
     * @description checks if account is within tier window if it has changed windows return true if both
     * @param Account account
     * @param Account_Maturity_Tier__c curTier - tier in current iteration above
     * @param Account_Maturity_Tier__c nextTier - tier above next tier
     * @return {boolean} - if number of closed opps are greater than or equal to the current tier AND less then then the next AND the values do not match 
     * than the tier has changed
    **/
    public static Boolean accountTierChanged( Account account, Account_Maturity_Tier__c curTier, Account_Maturity_Tier__c nextTier ){
        Boolean tierChanged = account.Number_of_Won_Opportunities__c >= curTier.Count_Floor__c && account.Maturity__c != curTier.Label__c;

        // if nextTier is not null then curTier is NOT the last tier then evaluate against the next tier
        if( nextTier != null ){
           tierChanged = tierChanged && account.Number_of_Won_Opportunities__c < nextTier.Count_Floor__c;
        }

        return tierChanged;
    }
}
