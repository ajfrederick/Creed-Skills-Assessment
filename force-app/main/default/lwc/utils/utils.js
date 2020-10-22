import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const validateFields = (fields)=>{
    // use reduce to get an accumulation of validity from lightning-input
    const allValid = [...fields].reduce((validSoFar, input)=>{
        input.reportValidity();
        return validSoFar && input.checkValidity();
    });

    return allValid;
};

const getErrorString = (error)=>{
    let ret = 'Unknown Error';

    if( Array.isArray(error.body) ){
        ret = error.body.map(e => e.message).join(', ');
    } else 
    if( typeof error.body.message === 'string' ){
        ret = error.body.message;
    }

    return ret;
};

const getSuccessToast = (message)=>{
    if(!message) message = 'All changes saved.';

    return new ShowToastEvent({
        title : 'SUCCESS!',
        message : message,
        variant : 'success'
    });
};

const getErrorToast = (error)=>{
    const message = getErrorString(error);

    return new ShowToastEvent({
        title : 'Sorry but something went wrong!',
        message : message,
        variant : 'error',
        mode : 'sticky'
    });
};

export { validateFields, getErrorToast, getSuccessToast };