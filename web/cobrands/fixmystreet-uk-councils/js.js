(function(){
    if (typeof jQuery === 'undefined' || !jQuery.validator) {
        return;
    }
    var validNamePat = /\ba\s*n+on+((y|o)mo?u?s)?(ly)?\b/i;
    function valid_name(value, element) {
        return this.optional(element) || value.length > 5 && value.match( /\S/ ) && value.match( /\s/ ) && !value.match( validNamePat );
    }
    jQuery.validator.addMethod('validName', valid_name, translation_strings.name.required);
    jQuery.validator.addMethod('validNameU', valid_name, translation_strings.name.required);
})();
