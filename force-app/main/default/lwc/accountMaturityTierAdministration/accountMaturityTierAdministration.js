/**
 * IMPORTS
 **/
import { LightningElement, wire } from 'lwc';

// utils
import { validateFields, getErrorToast, getSuccessToast } from 'c/utils';

// apex methods
import getTiers from '@salesforce/apex/AccountMaturityTiers.getTiers';
import insertTier from '@salesforce/apex/AccountMaturityTiers.insertTier';
import updateTiers from '@salesforce/apex/AccountMaturityTiers.updateTiers';
import deleteTier from '@salesforce/apex/AccountMaturityTiers.deleteTier';

import TITLE from '@salesforce/label/c.Account_Maturity_Tier_Title';

// import object info dynamically to get labels for settings
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import ACCOUNT_MATURITY_TIER_SETTINGS from '@salesforce/schema/Account_Maturity_Tier__c';

// import field api names that we want
import LEVEL_FIELD from '@salesforce/schema/Account_Maturity_Tier__c.Level__c';
import NAME_FIELD from '@salesforce/schema/Account_Maturity_Tier__c.Name';
import LABEL_FIELD from '@salesforce/schema/Account_Maturity_Tier__c.Label__c';
import COUNT_FIELD from '@salesforce/schema/Account_Maturity_Tier__c.Count_Floor__c';

/**
 * MODULE VARIABLES
 **/
const SETTINGS_FIELD_API_NAMES = [
    LEVEL_FIELD.fieldApiName,
    NAME_FIELD.fieldApiName,
    LABEL_FIELD.fieldApiName,
    COUNT_FIELD.fieldApiName
];

let HEADER_ROW_LABELS = {};


/**
 * CLASS
 **/
export default class AccountMaturityTierAdministration extends LightningElement {

/**
 * PROPS
 **/

    // array for iterating in view
    tiers;
    // object of tiers by their Id for updating in model upon field change for 'two way' data binding
    tiersById;
    // new tier to create
    newTier;
    // fresh unmutated array of tiers for cancel
    tiersCopy;

    // labels for header row
    labels = HEADER_ROW_LABELS;
    // title pulled in from costum label
    title = TITLE;
    // loading state
    isLoading = false;
    // boolean to disable save button only enabled when changes are made or a new setting is created
    disableSave = true;

/**
 * INITIAL SETUP FUNCTIONS
 **/

    // wired function that gets labels from schema for the hearder row and places them in HEADER_ROW_LABELS object
    @wire( getObjectInfo, {objectApiName : ACCOUNT_MATURITY_TIER_SETTINGS})
    setLabels({data, error}){

        if(data){
            setHeaderLabels(data.fields);
        } else
        if( error ){
            console.log(error);
        }
    }

    // make initial server call in the connected life cycle hood
    connectedCallback(){
        this.getTiers();
    }

    // calls apex gets all tiers from server
    getTiers(){
        this.isLoading = true;
        
        this.handlePromise( getTiers() );
    }

    // handles the promise returned by all apex calls on this class
    handlePromise(promise){
        promise.then((tiers)=>{
            // if apex returned null then something went wrong throw to the catch block
            if( tiers == null ){
                throw new NullError();
            }
            // if the tiers prop is set then we know this is initial mounting and let's let the user know all their changes were saved
            if( this.tiers ) this.dispatchEvent( getSuccessToast() );

            this.reset(tiers);
        })
        .catch((error)=>{
            this.dispatchEvent( getErrorToast(error) );
        })
        .finally(()=>{
            this.isLoading = false;
        });
    }

    // reset function which gets called on every successful round trip to the server
    reset(tiers){
        // set main array
        this.tiers = tiers;
        // make a copy for cancel function
        this.tiersCopy = copy(tiers);
        // assign new object that helps enable targeting for data binding on event change
        this.tiersById = {};
        // fill object
        tiers.map((tier)=>{
            this.tiersById[tier.Id] = tier;
        });

        this.newTier = null;
        this.disableSave = true;
    }

/**
 * USER INTERACTION FUNCTIONS
 **/

    // adds new tier and enables the save button
    add(){
        if( this.newTier ) return;

        const level = this.tiers.length + 1;

        this.newTier = new Account_Maturity_Tier__c(level);

        this.disableSave = false;
    }

    // save function that validates all input fields
    save(){
        const fields = this.template.querySelectorAll('lightning-input');

        const valid = validateFields(fields);

        // proceed only if valid
        if( valid ){
            // set the spinner
            this.isLoading = true;

            // if newTier prop is set then we have a new tier so make an insert call
            if( this.newTier ){
                this.handlePromise( insertTier( {tier:this.newTier} ) );
            // otherwise update the tiers
            } else {
                this.handlePromise( updateTiers( {tiers:this.tiers} ) );
            }
        }
    }

    cancel(){
        this.reset(this.tiersCopy);
    }

    remove(event){
        if( !confirm('Are you sure you want to delete this record?') ) return;
        
        const id = event.target.dataset.recordId;
        const tier = this.tiersById[id];

        this.handlePromise( deleteTier({tier:tier}) );
    }

/**
 * DOM EVENT HANDLERS
 **/
    
    handleNameChange(event){
        this.handleDataChange(event.target, NAME_FIELD.fieldApiName);
    }

    handleLabelChange(event){
        this.handleDataChange(event.target, LABEL_FIELD.fieldApiName);
    }

    handleCountChange(event){
        this.handleDataChange(event.target, COUNT_FIELD.fieldApiName);
    }

    handleDataChange(el, fieldApiName){
        let id = el.dataset.recordId,
            value = el.value,
            tier;

        // if element data-record-id is null and newTier prop is not then the change event came from creating a new tier
        if( !id && this.newTier ){
            tier = this.newTier;
        } else {
            tier = this.tiersById[id];
        }

        tier[fieldApiName] = value;

        this.disableSave = false;
    }
}


/**
 * CONSTRUCTOR FUNCTIONS
 **/
// for creating new tier
function Account_Maturity_Tier__c(level){
    // take all the api names and add them to the constructed object
    SETTINGS_FIELD_API_NAMES.map((field)=>{
        this[field] = '';
    });
    // set level explicitly as it's 'read-only'
    this[LEVEL_FIELD.fieldApiName] = level;
};

function NullError(){
    this.body = {
        message : 'The return from the server in the AccountMaturityTierAdministration component was null. Please contact your administrator'
    };
};

/**
 * HELPER FUNCTIONS
 **/
function setHeaderLabels(fields){
    if( !fields ) return;

    const apiNames = SETTINGS_FIELD_API_NAMES.join(',');

    for( let key in fields ){
        let field = fields[key];

        if( apiNames.indexOf( field.apiName ) >= 0 ){
            HEADER_ROW_LABELS[field.apiName] = field.label;
        }
    }
};

function copy(array){
    let copy = [];

    array.map((obj)=>{
        copy.push({...obj});
    });

    return copy;
};