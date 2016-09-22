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
    /* Accordion on councils page */

  var allPanels = $('.accordion > .accordion-item .accordion-content').hide();
  var allSwitches = $('.accordion .accordion-switch');

  allSwitches.click(function() {
    if ($(this).hasClass('accordion-switch--open')) {
        return false;
    }
    allPanels.slideUp();
    allSwitches.removeClass('accordion-switch--open');
    $(this).addClass('accordion-switch--open');
    $(this).next().slideDown();
    return false;
  });
  allSwitches.first().click();
});
