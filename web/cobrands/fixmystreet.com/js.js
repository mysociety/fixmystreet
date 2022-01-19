(function(){
    if (!jQuery.validator) {
        return;
    }
    var validNamePat = /\ba\s*n+on+((y|o)mo?u?s)?(ly)?\b/i;
    function valid_name_factory(single) {
        return function(value, element) {
            return this.optional(element) || value.length > 5 && value.match(/\S/) && (value.match(/\s/) || (single && !value.match('.@.'))) && !value.match(validNamePat);
        };
    }
    // XXX this fn is duplicated at web/cobrands/fixmystreet-uk-councils/js.js
    function validUkPhone(phone_number, element) {
        phone_number = phone_number.replace( /\+44\(0\)/g, "+44" );
        phone_number = phone_number.replace( /\(|\)|\s+|-/g, "" );
        return this.optional( element ) || phone_number.length > 9 &&
            phone_number.match( /^(?:(?:00|\+)44|0)[0-9]{9,10}$/ );
    }
    jQuery.validator.addMethod('validName', valid_name_factory(0), translation_strings.name.required);
    jQuery.validator.addMethod('validNameU', valid_name_factory(1), translation_strings.name.required);
    // validate UK phone numbers
    jQuery.validator.addMethod('validUkPhone', validUkPhone, translation_strings.phone.ukFormat);

    jQuery('.big-green-banner').on('click', function(){
        if (typeof ga !== 'undefined') {
            ga('send', 'event', 'big-green-banner', 'click');
        }
    });
})();
