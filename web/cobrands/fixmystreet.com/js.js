(function(){
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
        $.cookie('has_seen_country_message', 1, {expires: 365, path: '/'});
    });

    if ( $('body.frontpage').length && -1 == navigator.userAgent.indexOf('Google Page Speed')) {
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

$(function(){
    // "Fold out" additional rows in pricing grid
    $('.js-extra-features').each(function(){
        var $t3 = $(this);
        var $t2 = $('<tbody>');
        var cols = $t3.find('tr').eq(0).children().length;

        $t2.addClass('pricing-table__show-more');
        $t2.html('<tr><td colspan="' + cols + '"><button class="button">Compare more features</button></td></tr>');
        $t2.on('click', '.button', function(){
            $t3.toggle();
        });

        $t2.insertBefore($t3);
        $t3.hide();
    });

    // Add tier names to cells, to be displayed on narrow screens
    $('.pricing-table thead th').each(function(){
        var $table = $(this).parents('.pricing-table');
        var colIndex = $(this).prevAll().length;

        // Ignore first column
        if (colIndex > 0) {
            var tierName = $(this).text();
            $table.find('tbody tr').each(function(){
                $(this).children().eq(colIndex).attr('data-tier-name', tierName);
            });
        }
    });

    // Hide the demo access form behind a button, to save space on initial page load
    $('.js-fms-pro-demo-form').each(function(){
        var $form = $(this);
        var $revealBtn = $('<button>').addClass('btn').text('Request access').on('click', function(){
            $form.slideDown(250, function(){
                $form.find('input[type="text"], input[type="text"]').eq(0).focus();
            });
            $(this).remove();
        }).insertAfter($form);
        $form.hide();
    });
});
