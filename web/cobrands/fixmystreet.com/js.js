jQuery.validator.addMethod('validName', function(value, element) {
    var validNamePat = /\ba\s*n+on+((y|o)mo?u?s)?(ly)?\b/i;
    return this.optional(element) || value.length > 5 && value.match( /\S/ ) && value.match( /\s/ ) && !value.match( validNamePat ); }, translation_strings.category );

$(function(){

    /* Front page banner for other countries */

    $('.top_banner__close').live('click', function() {
        $('.top_banner--country').hide();
        $.cookie('has_seen_country_message', 1, {expires: 365, path: '/'});
    });

    if ( $('body.frontpage').length ) {
        if (!$.cookie('has_seen_country_message')) {
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
