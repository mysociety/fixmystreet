jQuery.validator.addMethod('validName', function(value, element) {
    var validNamePat = /\ba\s*n+on+((y|o)mo?u?s)?(ly)?\b/i;
    return this.optional(element) || value.length > 5 && value.match( /\S/ ) && value.match( /\s/ ) && !value.match( validNamePat ); }, translation_strings.category );
