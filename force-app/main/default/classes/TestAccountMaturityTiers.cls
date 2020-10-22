/**
 * @name TestOpportunityTrigger
 * @description test class for Trigger for Opportunity Object
**/
@isTest
public class TestAccountMaturityTiers {
   
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
     * @name insertTier
     * @description inserts tier using AccountMaturityTiers.cls also tests the getTiers() method
    **/
    @isTest
    static void insertTier(){
        // get Account inserted above
        Account acc = [SELECT 
            Id,
            Maturity__c 
                FROM Account 
                LIMIT 1][0];

        System.assertEquals( 'Young', acc.Maturity__c );
        
        // insert 50 opps
        insert TestOpportunityTrigger.getClosedWonOpportunities(200, acc.Id);

        // requery account for fresh reference
        acc = [SELECT 
            Id,
            Maturity__c ,
            Number_of_Won_Opportunities__c
                FROM Account 
                LIMIT 1][0];

        // maturity is sage since we only have a top tier at 100 inserted above
        System.assertEquals( 'Sage', acc.Maturity__c );
        System.assertEquals( 200, acc.Number_of_Won_Opportunities__c );

        Account_Maturity_Tier__c tier = new Account_Maturity_Tier__c(
            Name = 'Tier 4',
            Label__c = 'Guru',
            Level__c = 4,
            Count_Floor__c = 200
        );

        // since insertTier() runs batch apex let's put it in a start/stop context to have it actually run
        Test.startTest();
            AccountMaturityTiers.insertTier( tier );
        Test.stopTest();

        Account_Maturity_Tier__c[] allTiers = AccountMaturityTiers.getTiers();

        System.assertEquals( 4, allTiers.size() );

        // requery account for fresh reference
        acc = [SELECT 
            Id,
            Maturity__c ,
            Number_of_Won_Opportunities__c
                FROM Account 
                LIMIT 1][0];
        
        // since we inserted a new tier with a Count_Floor__c of 200 and the account above has 200 opporutunities
        // then the account will be updated to the new Tier's Label__c of Guru
        System.assertEquals( 'Guru', acc.Maturity__c );
        System.assertEquals( 200, acc.Number_of_Won_Opportunities__c );
    }

    /**
     * @name updateTiers
     * @description updates tier using AccountMaturityTiers.cls
    **/
    @isTest
    static void updateTiers(){
        // get Account inserted above
        Account acc = [SELECT 
            Id,
            Maturity__c 
                FROM Account 
                LIMIT 1][0];

        System.assertEquals( 'Young', acc.Maturity__c );
        
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

        // get Tier 2 and update count to be above the amount of opps our acount has
        Account_Maturity_Tier__c tier2 = Account_Maturity_Tier__c.getInstance('Tier 2');
        tier2.Count_Floor__c = 51;

        

        // since updateTiers() runs batch apex let's put it in a start/stop context to have it actually run
        Test.startTest();
            // put in list since updateTiers() expects a list of tiers as param
            Account_Maturity_Tier__c[] tiers = new Account_Maturity_Tier__c[]{tier2};
            AccountMaturityTiers.updateTiers( tiers );
        Test.stopTest();

        // requery account for fresh reference
        acc = [SELECT 
            Id,
            Maturity__c ,
            Number_of_Won_Opportunities__c
                FROM Account 
                LIMIT 1][0];
        
        // since we updated the tier2 count to be 51 opps and the account only has 50 opps than the account will now be demoted to 'Young'
        System.assertEquals( 'Young', acc.Maturity__c );
    }

    /**
     * @name deleteTier
     * @description deletes tier using AccountMaturityTiers.cls
    **/
    @isTest
    static void deleteTier(){
        // get Account inserted above
        Account acc = [SELECT 
            Id,
            Maturity__c 
                FROM Account 
                LIMIT 1][0];

        System.assertEquals( 'Young', acc.Maturity__c );
        
        // insert 50 opps
        insert TestOpportunityTrigger.getClosedWonOpportunities(100, acc.Id);

        // requery account for fresh reference
        acc = [SELECT 
            Id,
            Maturity__c ,
            Number_of_Won_Opportunities__c
                FROM Account 
                LIMIT 1][0];
                
        System.assertEquals( 100, acc.Number_of_Won_Opportunities__c );
        System.assertEquals( 'Sage', acc.Maturity__c );

        Account_Maturity_Tier__c tier3 = Account_Maturity_Tier__c.getInstance('Tier 3');

        Test.startTest();
            AccountMaturityTiers.deleteTier( tier3 );
        Test.stopTest();

        // requery account for fresh reference
        acc = [SELECT 
            Id,
            Maturity__c ,
            Number_of_Won_Opportunities__c
                FROM Account 
                LIMIT 1][0];
        
        // account still has 100 'Closed Won' Opportunities but it's updated to have a maturity of of 'Mature' since we deleted 'Sage'
        System.assertEquals( 100, acc.Number_of_Won_Opportunities__c );
        System.assertEquals( 'Mature', acc.Maturity__c );
    }

    /**
     * @name testInvalid
     * @description set a tier below another to a count above that of it's superior
    **/
    @isTest
    static void testValidator(){
        Account_Maturity_Tier__c[] tiers = AccountMaturityTiers.getTiers();
        // set first tier above 51 since the next tier count is 50
        tiers[0].Count_Floor__c = 51;

        AccountMaturityTiers.TierValidator validator = new AccountMaturityTiers.TierValidator(tiers);

        System.assertEquals( false, validator.valid() );
        System.assertNotEquals( null, validator.getMessage() );
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
