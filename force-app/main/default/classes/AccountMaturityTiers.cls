/**
 * @name AccountMaturityTiers
 * @description Class to help deliver custom settings data to lightning component accountMaturityTierAdministration
**/
public with sharing class AccountMaturityTiers {

/**
 * GET
**/

    /**
     * @name getTiers
     * @description called from OpportunityHelper and lighting component accountMaturityTierAdministration and returns custom settings Account_Maturity_Tier__c
     * @return Account_Maturity_Tier__c[] - all instances of custom settings Account Maturity Tier
    **/
    @AuraEnabled
    public static Account_Maturity_Tier__c[] getTiers(){
        Account_Maturity_Tier__c[] tiers = Account_Maturity_Tier__c.getAll().values();     
        
        return AccountMaturityTiers.sortTiers( tiers, 'Count_Floor__c' );
    }

/**
 * DML
**/

    /**
     * @name insertTier
     * @description called from lighting component accountMaturityTierAdministration
     * @param Account_Maturity_Tier__c tier
     * @return Account_Maturity_Tier__c[] - all instances of custom settings Account Maturity Tier
    **/
    @AuraEnabled
    public static Account_Maturity_Tier__c[] insertTier( Account_Maturity_Tier__c tier ){
        if( tier == null ) return null;

        // get all other current tiers for validation
        Account_Maturity_Tier__c[] tiers = AccountMaturityTiers.getTiers();
        tiers.add(tier);

        // create new instance of internal validator class
        TierValidator validator = new TierValidator(tiers);
        
        Account_Maturity_Tier__c[] ret;

        // set save point to rollback all changes if insert fails or accounts fall to update
        Savepoint sp = Database.setSavePoint();

        if( validator.valid() ){

            try {

                insert tier;
                AccountMaturityTiers.updateAllAccounts();
                ret = AccountMaturityTiers.getTiers();
    
            } catch( Exception e ){
                Database.rollback(sp);
                System.debug( 'Error in catch on insertTiers() on AccountMaturityTiers.cls' + ' \n Error Detail: ' + e.getMessage() );
            }

        } else {
            throw new TierException( validator.getMessage() );
        }

        return ret;
    }
    
    /**
     * @name updateTiers
     * @description called from lighting component accountMaturityTierAdministration
     * @param Account_Maturity_Tier__c[] tiers
     * @return Account_Maturity_Tier__c[] - all instances of custom settings Account Maturity Tier
    **/
    @AuraEnabled
    public static Account_Maturity_Tier__c[] updateTiers( Account_Maturity_Tier__c[] tiers ){
        // check input
        if( tiers.size() == 0 ) return null;

        // create new instance of internal validator class
        TierValidator validator = new TierValidator(tiers);
 
        Account_Maturity_Tier__c[] ret;

        // set save point to rollback all changes if update fails or accounts fall to update
        Savepoint sp = Database.setSavePoint();

        if( validator.valid() ){

            try {

                update tiers;
                AccountMaturityTiers.updateAllAccounts();
                ret = AccountMaturityTiers.getTiers();
    
            } catch( Exception e ){
                Database.rollback(sp);
                System.debug( 'Error in catch on updateTiers() on AccountMaturityTiers.cls' + ' \n Error Detail: ' + e.getMessage() );
            }

        } else {
            throw new TierException( validator.getMessage() );
        }

        return ret;
    }

     /**
     * @name deleteTier
     * @description called from lighting component accountMaturityTierAdministration
     * @param Account_Maturity_Tier__c tier
     * @return Account_Maturity_Tier__c[] - all instances of custom settings Account Maturity Tier
    **/
    @AuraEnabled
    public static Account_Maturity_Tier__c[] deleteTier( Account_Maturity_Tier__c tier ){
        if( tier == null ) return null;

        Account_Maturity_Tier__c[] ret;

        // set save point to rollback all changes if update fails or accounts fall to update
        Savepoint sp = Database.setSavePoint();

        try {

            delete tier;
            AccountMaturityTiers.updateAllAccounts();
            ret = AccountMaturityTiers.getTiers();

        } catch( Exception e ){
            Database.rollback(sp);
            System.debug( 'Error in catch on deleteTier() on AccountMaturityTiers.cls' + ' \n Error Detail: ' + e.getMessage() );
        }

        return ret;
    }

/**
 * UTILITIES
**/

    /**
     * @name updateAllAccounts
     * @description updates all accounts since tiers change. Uses async batch to avoid limits
    **/
    public static void updateAllAccounts(){
        BatchUpdateAccountMaturity batch = new BatchUpdateAccountMaturity( new Set<Id>() );
        Database.executeBatch( batch );
    }

    /**
     * @name sortTiersByCount
     * @description sorts tiers by count in ascending order
     * @param Account_Maturity_Tier__c[] tiers
     * @return Account_Maturity_Tier__c[]
    **/
    public static Account_Maturity_Tier__c[] sortTiers( sObject[] objs, String fieldName ){
        // since custom settings don't have an order by here is sorting algorithm
        Map<Decimal, Account_Maturity_Tier__c> tiersByCount = new Map<Decimal, Account_Maturity_Tier__c>();

        for( sObject obj : objs ){
            tiersByCount.put( (Decimal) obj.get(fieldName), (Account_Maturity_Tier__c) obj );
        }

        // make a list out of the keyset to sort since sets are unordered
        List<Decimal> countSorted = new List<Decimal>(tiersByCount.keyset());
        countSorted.sort();

        Account_Maturity_Tier__c[] sortedTiers = new Account_Maturity_Tier__c[]{};

        for( Decimal count : countSorted ){
            Account_Maturity_Tier__c tier = tiersByCount.get(count);

            sortedTiers.add(tier);
        }

        return sortedTiers;
    }

/**
 * INTERNAL CLASSES
**/

    /**
     * @name TierValidator 
     * @description internal validator class
    **/
    public class TierValidator {
        
        // lasy load list of all tier settings
        private Account_Maturity_Tier__c[] tiers {
            get {
                if( tiers == null ){
                    tiers = new Account_Maturity_Tier__c[]{};
                }

                return tiers;
            }
            set;
        }

        // lazy load list assignment of tiers that fail validation only when invalid
        private Account_Maturity_Tier__c[] errorTiers {
            get {
                if( errorTiers == null ){
                    errorTiers = new Account_Maturity_Tier__c[]{};
                }

                return errorTiers;
            }
            set;
        }

        // state of validity
        private Boolean isValid {get;set;}
        
        // construcor
        public TierValidator( Account_Maturity_Tier__c[] ts ){
            tiers.addAll(ts);
            isValid = true;
            validate();
        }

        /**
         * @name valid
         * @description 
         * @return boolean - state of validity
        **/
        public Boolean valid(){
            return isValid;
        }

        /**
         * @name getMessage
         * @description makes error message if invalid
         * @return boolean - readable error message
        **/
        public String getMessage(){
            if( errorTiers.size() < 2 ) return null;

            Account_Maturity_Tier__c tier1 = errorTiers[0];
            Account_Maturity_Tier__c tier2 = errorTiers[1];

            String ret = '';
            
            ret += tier1.Name + ' count of ' + tier1.Count_Floor__c;
            ret += ' cannot be great than or equal to ';
            ret += tier1.Name + ' count of ' + tier1.Count_Floor__c;

            return ret;
        }

        /**
         * @name validate
         * @description validates our tiers since custom settings don't have validation rules
         * @return boolean - valid if each tier does not overlap another
        **/
        private void validate(){
            // get out if there's only one tier
            if( tiers.size() == 1 ){ return; }

            Account_Maturity_Tier__c[] sortedTiers = AccountMaturityTiers.sortTiers( tiers, 'Level__c' );

            // loop through tiers and check the next tier against the previous one
            for( Integer i = 0; i < sortedTiers.size(); i++ ){
                if( i == 0 ) continue;

                Account_Maturity_Tier__c prevTier = sortedTiers.get(i-1);
                Account_Maturity_Tier__c curTier = sortedTiers.get(i);

                // if the previous tier's count is greater than or equal to current tiers than it's not valid and bounce
                if( prevTier.Count_Floor__c >= curTier.Count_Floor__c  ){
                    isValid = false;

                    errorTiers.add(prevTier);
                    errorTiers.add(curTier);

                    break;
                }
            }
        }
    }

/**
 * MISC
**/

    /**
     * @name TierException
     * @description extends SF Exception class to throw custom exception if our TierValidators fails
    **/
    public class TierException extends Exception {}
}
