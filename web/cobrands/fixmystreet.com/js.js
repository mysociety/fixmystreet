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
    jQuery.validator.addMethod('validName', valid_name_factory(0), translation_strings.name.required);
    jQuery.validator.addMethod('validNameU', valid_name_factory(1), translation_strings.name.required);
})();
