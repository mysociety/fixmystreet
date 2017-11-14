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

$(function(){

    /* Front page banner for other countries */

    $('.top_banner__close').live('click', function() {
        $('.top_banner--country').hide();
        var t = new Date(); t.setFullYear(t.getFullYear() + 1);
        document.cookie = 'has_seen_country_message=1; path=/; expires=' + t.toUTCString();
    });

    if ( $('body.frontpage').length && -1 == navigator.userAgent.indexOf('Google Page Speed')) {
        if (document.cookie.indexOf('has_seen_country_message') === -1) {
            $.ajax({
                url: 'https://gaze.mysociety.org/gaze-rest?f=get_country_from_ip',
                success: function(data) {
                    if ( data && data != 'GB\n' ) {
                        var banner = '<div class="top_banner top_banner--country"><a href="#" class="top_banner__close">Close</a> <p>This site is for reporting <strong>problems in the UK</strong>. There are FixMyStreet sites <a href="http://www.fixmystreet.org/sites/">all over the world</a>, or you could set up your own using the <a href="http://www.fixmystreet.org/">FixMyStreet Platform</a>.</p></div>';
                        $('body').prepend(banner);
                        $('.top_banner--country').slideDown('slow');
                    }
                }
            });
        }
    }

});
