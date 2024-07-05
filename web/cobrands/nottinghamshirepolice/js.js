(function(){
    if (!jQuery.validator) {
        return;
    }

    function notContainsEmail(value, element) {
        return this.optional(element) ||
            !/[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@(?:\S{1,63})/.test(value);
    }

    jQuery.validator.addMethod('notContainsEmail', notContainsEmail,
        'Report cannot contain an email address');
})();

body_validation_rules = {
    'Immediate Justice Team': {
        title: {
            required: true,
            notContainsEmail: true
        },
        detail: {
            required: true,
            notContainsEmail: true
        }
    }
};
