///*
(function(){
    $(document).on('change', '#defect_item_category', function(){
        var item = document.getElementById('defect_item_category');
        var type = document.getElementById('defect_item_type');
        var detail = document.getElementById('defect_item_detail');
        var opt = item.options[item.selectedIndex].value;
        // reset all if '-- Pick' option chosen
        if (item.selectedIndex === 0){
            type.selectedIndex = 0;
            detail.selectedIndex = 0;
            return;
        }
        var event = document.createEvent("Event");
        event.initEvent("change", true, false);
        type.dispatchEvent(event);
        var optgroups = type.children;
        // don't get stuck on stale options
        // start at 1 to miss out '-- Pick a type --'
        for (var i=1; i<optgroups.length; i++) {
            var group = optgroups[i];
            var regex = new RegExp(opt);
            if (regex.test(group.label)) {
                // select first option of correct type
                group.querySelector('option:first-child').selected = true;
                break;
            }
        }
        // now process detail dropdown to match type
        show_relevant_details();
    });

    $(document).on('change', '#defect_item_type', function(){
        show_relevant_details();
    });

    function show_relevant_details() {
        var type = document.getElementById('defect_item_type');
        var selected = type.selectedOptions;
        var detail = document.getElementById('defect_item_detail');
        // find text value & optgroup label of selected defect type
        var type_text = selected[0].innerText;
        var type_label = selected[0].parentElement.label;
        // hide all detail options, then show options of correct type
        var optgroups = detail.children;
        // handle type being manually set to -- Pick a type --
        if (/--/.test(type_text)) {
            // set to -- Pick a detail --
            detail.selectedIndex = 0;
            // show all groups
            for (var i=1; i<optgroups.length; i++) {
                optgroups[i].style.display = '';
            }
        } else {
            var type_source;
            if (type_label === 'Kerbing' || type_label === 'Drainage') {
                type_source = type_label;
            } else {
                type_source = type_text;
            }
            // start at 1 to always show -- Pick a detail --
            for (var j=1; j<optgroups.length; j++) {
                var group = optgroups[j];
                var detail_text = group.label;
                // hide any groups that don't match the defect type
                if (detail_text === type_source) {
                    // show this group
                    group.style.display = '';
                    // select first detail option of correct type
                    group.querySelector('option:first-child').selected = true;
                } else {
                    group.style.display = 'none';
                }
            }
        }
    }

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
                top: '160px',
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
//*/
