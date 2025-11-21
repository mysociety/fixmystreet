(function(){
    $.extend(fixmystreet.set_up, {
        map_sidebar_key_tools_2: function() {
            // Similar to main one but for key-tool-area
            if ($('html.mobile').length) {
                $('#key-tool-area').off('click.wards');
                $('#key-tool-area').on('click.wards', function(e) {
                    e.preventDefault();
                    $('#key-tools').addClass('area-js');
                    $('#council_wards').slideToggle('800', function() {
                      $('#key-tool-division').toggleClass('hover');
                    });
                });
            } else {
                $('#key-tool-area').drawer('council_wards', false);
            }
        },

        sub_item_key_tools_areas: function() {
            var $sidebar = $('#map_sidebar');
            var drawer_css = {
                position: 'fixed',
                zIndex: 10,
                top: '64px',
                bottom: 0,
                width: $sidebar.css('width'),
                paddingLeft: $sidebar.css('padding-left'),
                paddingRight: $sidebar.css('padding-right'),
                overflow: 'auto',
                background: '#fff'
            };
            drawer_css[isR2L() ? 'right' : 'left'] = 0;

            if ($('html.mobile').length) {
                $('.sub-area-item a').on('click', function(e) {
                    e.preventDefault();
                    $('[id^=key-tool-]').removeClass('hover');
                    $(this).addClass('hover');
                    $('.js-sub-area-list').addClass('hidden-js');
                    var href = this.getAttribute('href');
                    $(href).removeClass('hidden-js').find('h2').hide();
                });
            } else {
                $('.sub-area-item a').on('click', function(e) {
                    e.preventDefault();
                    $('[id^=key-tool-]').removeClass('hover');
                    $(this).addClass('hover');
                    $('.js-sub-area-list').addClass('hidden-js');
                    var href = this.getAttribute('href');
                    $(href).css(drawer_css).removeClass('hidden-js').find('h2').css({ marginTop: 0 });
                    $('#key-tools-wrapper').addClass('static').prependTo(href);
                });
            }
        }
    });
})();
