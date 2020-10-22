trigger OpportunityTrigger on Opportunity ( 
    before insert, 
    before update,
    before delete,
    after insert, 
    after update,
    after delete,
    after undelete
) {
    if( Trigger.isBefore ){
        if( Trigger.isInsert ){

        } else 
        if( Trigger.isUpdate ){

        } else 
        if( Trigger.isDelete ){

        }
    } else 
    if( Trigger.isAfter ){
        if( Trigger.isInsert ){
            OpportunityHelper.afterInsert( Trigger.new );
        } else 
        if( Trigger.isUpdate ){
            OpportunityHelper.afterUpdate( Trigger.oldMap, Trigger.newMap );
        } else 
        if( Trigger.isDelete ){
            OpportunityHelper.afterDelete( Trigger.old, Trigger.new );
        }  else 
        if( Trigger.isUndelete ){
            OpportunityHelper.afterUndelete( Trigger.old, Trigger.new );
        }  
    }
}