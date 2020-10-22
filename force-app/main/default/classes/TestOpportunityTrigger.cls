/**
 * @name TestOpportunityTrigger
 * @description test class for Trigger for Opportunity Object
**/
@isTest
public class TestOpportunityTrigger {
    
    /**
     * @name makeData
     * @description inserts accounts and opportunities for this test class
    **/
    @TestSetup
    static void makeData(){
        // make account
        insert new Account(Name='New Account');

        // make settings
        Account_Maturity_Tier__c[] settings = new Account_Maturity_Tier__c[]{};

        String[] labels = new String[]{'Young','Mature','Sage'};

        Integer[] counts = new Integer[]{0,50,100};

        for( Integer i = 0; i < 3; i++ ){
            Integer level = i+1;

            settings.add( new Account_Maturity_Tier__c(
                Name = 'Tier ' + level,
                Label__c = labels[i],
                Level__c = level,
                Count_Floor__c = counts[i]
            ));
        }

        insert settings;
    }

    /**
     * @name insertOpportunities
     * @description tests trigger logic for on insert of opportunities
    **/
    @isTest
    static void insertOpportunities(){
        // get Account inserted above
        Account acc = [SELECT 
            Id,
            Maturity__c 
                FROM Account 
                LIMIT 1][0];

        System.assertEquals( acc.Maturity__c, 'Young' );
        
        // insert 50 opps
        insert TestOpportunityTrigger.getClosedWonOpportunities(50, acc.Id);

        // requery account for fresh reference
        acc = [SELECT 
            Id,
            Maturity__c ,
            Number_of_Won_Opportunities__c
                FROM Account 
                LIMIT 1][0];
                
        System.assertEquals( 50, acc.Number_of_Won_Opportunities__c );
        System.assertEquals( 'Mature', acc.Maturity__c );

        // insert 50 more
        insert TestOpportunityTrigger.getClosedWonOpportunities(50, acc.Id);

        // requery account for fresh reference
        acc = [SELECT 
            Id,
            Maturity__c ,
            Number_of_Won_Opportunities__c
                FROM Account 
                LIMIT 1][0];
                
        System.assertEquals( 100, acc.Number_of_Won_Opportunities__c );
        System.assertEquals( 'Sage', acc.Maturity__c ); 
    }

    /**
     * @name updateOpportunities
     * @description tests trigger logic for on update of opportunities
    **/
    @isTest
    static void updateOpportunities(){
        // get Account inserted above
        Account acc = [SELECT 
            Id,
            Maturity__c 
                FROM Account 
                LIMIT 1][0];

        System.assertEquals( acc.Maturity__c, 'Young' );
        
        // insert 49 opps
        insert TestOpportunityTrigger.getClosedWonOpportunities(49, acc.Id);

        Opportunity opp = new Opportunity(
            Name = 'New Opp',
            AccountId = acc.Id,
            CloseDate = Date.today(),
            StageName = 'Negotiation',
            Amount = 100
        );

        insert opp;

        // requery account for fresh reference
        acc = [SELECT 
            Id,
            Maturity__c ,
            Number_of_Won_Opportunities__c
                FROM Account 
                LIMIT 1][0];
                
        System.assertEquals( 49, acc.Number_of_Won_Opportunities__c );
        System.assertEquals( 'Young', acc.Maturity__c );

        opp.StageName = 'Closed Won';

        update opp;

        // requery account for fresh reference
        acc = [SELECT 
            Id,
            Maturity__c ,
            Number_of_Won_Opportunities__c
                FROM Account 
                LIMIT 1][0];
                
        System.assertEquals( 50, acc.Number_of_Won_Opportunities__c );
        System.assertEquals( 'Mature', acc.Maturity__c );
    }

    /**
     * @name deleteAndUndeleteOpportunities
     * @description tests trigger logic for on delete and undelete of opportunities
    **/
    @isTest
    static void deleteAndUndeleteOpportunities(){
        // get Account inserted above
        Account acc = [SELECT 
            Id,
            Maturity__c 
                FROM Account 
                LIMIT 1][0];

        System.assertEquals( acc.Maturity__c, 'Young' );
        
        // insert 49 opps
        insert TestOpportunityTrigger.getClosedWonOpportunities(50, acc.Id);

        // query for random opp
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1][0];

        delete opp;

        // requery account for fresh reference
        acc = [SELECT 
            Id,
            Maturity__c ,
            Number_of_Won_Opportunities__c
                FROM Account 
                LIMIT 1][0];
                
        System.assertEquals( 49, acc.Number_of_Won_Opportunities__c );
        System.assertEquals( 'Young', acc.Maturity__c );

        undelete opp;

        // requery account for fresh reference
        acc = [SELECT 
            Id,
            Maturity__c ,
            Number_of_Won_Opportunities__c
                FROM Account 
                LIMIT 1][0];
                
        System.assertEquals( 50, acc.Number_of_Won_Opportunities__c );
        System.assertEquals( 'Mature', acc.Maturity__c );
    }
    
    /**
     * @name changeAccountOnOpportunity
     * @description tests trigger logic for when a 'Closed Won' opportunities account changes
    **/
    @isTest
    static void changeAccountOnOpportunity(){
        // get Account inserted above
        Account acc = [SELECT 
            Id,
            Maturity__c 
                FROM Account 
                LIMIT 1][0];

        System.assertEquals( acc.Maturity__c, 'Young' );
        
        // insert 50 opps
        insert TestOpportunityTrigger.getClosedWonOpportunities(50, acc.Id);

        // requery account for fresh reference
        acc = [SELECT 
            Id,
            Maturity__c ,
            Number_of_Won_Opportunities__c
                FROM Account 
                LIMIT 1][0];

        System.assertEquals( 50, acc.Number_of_Won_Opportunities__c );
        System.assertEquals( 'Mature', acc.Maturity__c );

        // make a new account
        Account newAccount = new Account(Name = 'New Account 2');
        insert newAccount;

        // requery newAccount to get Id
        newAccount = [SELECT 
            Id,
            Maturity__c ,
            Number_of_Won_Opportunities__c
                FROM Account
                WHERE Name = 'New Account 2'];

        System.assertEquals( 0, newAccount.Number_of_Won_Opportunities__c );
        System.assertEquals( 'Young', newAccount.Maturity__c );

        // query for random opp
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1][0];
        opp.AccountId = newAccount.Id;

        update opp;

        // requery newAccount for fresh reference
        newAccount = [SELECT 
            Id,
            Maturity__c ,
            Number_of_Won_Opportunities__c
                FROM Account
                WHERE Id = :newAccount.Id];
        
        // since we updated opportunity's above account to newAccount then it should have 1 won opp and will still be 'Young'
        System.assertEquals( 1, newAccount.Number_of_Won_Opportunities__c );
        System.assertEquals( 'Young', newAccount.Maturity__c );
        
        // requery FIRST account for fresh reference
        acc = [SELECT 
            Id,
            Maturity__c ,
            Number_of_Won_Opportunities__c
                FROM Account 
                WHERE Id = :acc.Id];

        // since the opps account changed away from this account then there will be one less won opp 
        // and it will be downgraded to 'Young' since the cutoff is 50
        System.assertEquals( 49, acc.Number_of_Won_Opportunities__c );
        System.assertEquals( 'Young', acc.Maturity__c );
    }

    /**
     * @name testBatch
     * @description tests batch class BatchUpdateAccountMaturity
    **/
    @isTest
    static void testBatch(){
        // get Account inserted above
        Account acc = [SELECT 
            Id,
            Maturity__c 
                FROM Account 
                LIMIT 1][0];

        insert TestOpportunityTrigger.getClosedWonOpportunities(50, acc.Id);
        
        acc = [SELECT 
            Id,
            Maturity__c 
                FROM Account 
                LIMIT 1][0];

        System.assertEquals( 'Mature', acc.Maturity__c );

        // we're gonna grab a tier and update it's count so simulate user update
        // in the system this would cause a batch update accounts async event
        Account_Maturity_Tier__c tier2 = Account_Maturity_Tier__c.getInstance('Tier 2');
        tier2.Count_Floor__c = 51;

        update tier2;

        // start test to stop which simulates a start and end to async events for test
        Test.startTest();
            Set<Id> accIds = new Set<Id>();
            accIds.add(acc.Id);

            BatchUpdateAccountMaturity batch = new BatchUpdateAccountMaturity( accIds );
            Database.executeBatch( batch );
        Test.stopTest();

        acc = [SELECT 
            Id,
            Maturity__c 
                FROM Account 
                LIMIT 1][0];

        System.assertEquals( 'Young', acc.Maturity__c );
    }

/**
 * UTILITY METHODS
**/

    /**
     * @name getClosedWonOpportunities
     * @description makes 'Closed Won' Opportunities
     * @return List<Opportunity>
    **/
    public static Opportunity[] getClosedWonOpportunities( Integer count, Id accId ){
        Opportunity[] opps = new Opportunity[]{};

        for( Integer i = 0; i < count; i++ ){
            Opportunity opp = new Opportunity(
                Name = 'New Opp ' + i,
                AccountId = accId,
                CloseDate = Date.today(),
                StageName = 'Closed Won',
                Amount = 100
            );

            opps.add(opp);
        }

        return opps;
    }
}