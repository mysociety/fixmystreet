(function() {

    // Store a reference to the "duplicate" report pins so we can
    // quickly remove them when we’re finished showing duplicates.
    var current_duplicate_markers;

    // keep track of whether the suggestion UI has already been dismissed
    // for this category
    var dismissed = false;
    var dismissed_category = null;

    // Report ID will be available on report inspect page,
    // but undefined on new report page.
    var report_id = $("#report_inspect_form .js-report-id").text() || undefined;

    // Don't make another call whilst one is in progress
    var in_progress = false;

    function refresh_duplicate_list(evt, params, category) {
        if (params && params.skip_duplicates) {
            return;
        }

        if (in_progress) {
            return;
        }

        if (!category) {
            category = $('select[name="category"]').val();
        }
        if (category === '-- Pick a category --') {
            return;
        }

        var nearby_url;
        var url_params = {
            filter_category: category,
            latitude: $('input[name="latitude"]').val(),
            longitude: $('input[name="longitude"]').val()
        };

        if ( report_id ) {
            nearby_url = '/report/' + report_id + '/nearby.json';
            url_params.distance = 1000; // Inspectors might want to see reports fairly far away (1000 metres)
            url_params.pin_size = 'small'; // How it's always been
        } else {
            nearby_url = '/around/nearby';
            url_params.distance = 250; // Only want to bother public with very nearby reports (250 metres)
            url_params.pin_size = 'normal';
        }

        if ($('html').hasClass('mobile')) {
            url_params.inline_maps = 1;
        }

        if (category && params && params.check_duplicates_dismissal ) {
            dismissed = category === dismissed_category;
            dismissed_category = category;

            if (!take_effect()) {
                remove_duplicate_pins();
                remove_duplicate_list();
                return;
            }
        }

        in_progress = true;
        $.ajax({
            url: nearby_url,
            data: url_params,
            dataType: 'json'
        }).done(function(response) {
            if (response.pins.length && take_effect()) {
                render_duplicate_list(response);
                render_duplicate_pins(response);
            } else {
                remove_duplicate_pins();
                remove_duplicate_list();
            }
        }).fail(function(){
            remove_duplicate_pins();
            remove_duplicate_list();
        });
    }

    function render_duplicate_list(api_response) {
        var $reports = $( api_response.reports_list );

        var duplicate_of = $('#report_inspect_form [name="duplicate_of"]').val();
        if ( duplicate_of ) {
            $reports.filter('[data-report-id="' + duplicate_of + '"]')
                .addClass("item-list__item--selected");
        }

        $("#js-duplicate-reports ul").empty().prepend( $reports );
        fixmystreet.set_up.fancybox_images();

        $('#js-duplicate-reports').hide().removeClass('hidden').slideDown(function(){
            in_progress = false;
        });
        if ( $('#problem_form').length ) {
            $('.js-hide-if-invalid-category').slideUp();
            $('.js-hide-if-invalid-category_extras').slideUp();
        }

        if (!fixmystreet.map.events.extensions.buttonclick.isDeviceTouchCapable) {
            // Highlight map pin when hovering associated list item.
            // (not on touchscreens though because a) the 'mouseenter' handler means
            // two taps are required on the 'read more' button - one to highlight
            // the list item and another to activate the button- and b) the pins
            // might be scrolled off the top of the screen anyway e.g. on phones)
            var timeout;
            $reports.on('mouseenter', function(){
                var id = parseInt( $(this).data('reportId'), 10 );
                clearTimeout( timeout );
                fixmystreet.maps.markers_highlight( id );
            }).on('mouseleave', function(){
                timeout = setTimeout( fixmystreet.maps.markers_highlight, 50 );
            });
        }

        // Add a "select this report" button, when on the report inspect form.
        if ( $('#report_inspect_form').length ) {
            $reports.each(function(){
                var $button = $('<button>').addClass('btn btn--small btn--primary');
                $button.text(translation_strings.this_report);
                $button.on('click', function(e) {
                    e.preventDefault(); // Prevent button from submitting parent form
                    var report_id = $(this).closest('li').data('reportId');
                    $('#report_inspect_form [name="duplicate_of"]').val(report_id);
                    $(this).closest('li')
                        .addClass('item-list__item--selected')
                        .siblings('.item-list__item--selected')
                        .removeClass('item-list__item--selected');
                });
                $(this).find('.item-list__item--expandable__actions').append($button);
            });
        }

        // Add a "track this report" button when on the regular reporting form.
        if ( $('#problem_form').length ) {
            $reports.each(function() {
                var $li = $(this);
                var id = parseInt( $li.data('reportId'), 10 );
                var alert_url = '/alert/subscribe?id=' + encodeURIComponent(id);
                var $button = $('<a>').addClass('btn btn--small btn--primary');
                $button.text(translation_strings.this_is_the_problem);
                $button.attr('href', alert_url);
                $button.on('click', function(e){
                    e.preventDefault();
                    var $div = $('.js-template-get-updates > div').clone();
                    $div.find('input[name="id"]').val(id);
                    $div.find('input[disabled]').prop('disabled', false);
                    $div.hide().appendTo($li).slideDown(250, function(){
                        $div.find('input[type="email"]').focus();
                    });
                    $li.find('.item-list__item--expandable__actions').slideUp(250);
                    $li.removeClass('js-expandable');
                    $li.addClass('item-list__item--selected');
                });
                $li.find('.item-list__item--expandable__actions').append($button);
            });
        }
    }

    function render_duplicate_pins(api_response) {
        if (!fixmystreet.markers) {
            return;
        }
        var markers = fixmystreet.maps.markers_list( api_response.pins, true );
        fixmystreet.markers.removeFeatures( current_duplicate_markers );
        fixmystreet.markers.addFeatures( markers );
        current_duplicate_markers = markers;

        // Hide any asset layer that might be visible and get confused with the duplicates
        var layers = fixmystreet.map.getLayersBy('assets', true);
        for (var i = 0; i<layers.length; i++) {
            if (!layers[i].fixmystreet.always_visible && layers[i].getVisibility()) {
                layers[i].setVisibility(false);
            }
        }
    }

    function remove_duplicate_list() {
        $('#js-duplicate-reports').slideUp(function(){
            $(this).addClass('hidden');
            $(this).find('ul').empty();
            in_progress = false;
        });
        if ($('#problem_form').length && take_effect()) {
            $('.js-hide-if-invalid-category').slideDown();
            $('.js-hide-if-invalid-category_extras').slideDown();
        }
    }

    function remove_duplicate_pins() {
        if (!fixmystreet.markers) {
            return;
        }
        fixmystreet.markers.removeFeatures( current_duplicate_markers );

        // In order to reinstate a hidden assets layer, let's pretend we've
        // just picked the category anew, but skip ourselves
        $(fixmystreet).trigger('report_new:category_change', { skip_duplicates: true });
    }

    function inspect_form_state_change() {
        // The duplicate report list only makes sense when state is 'duplicate'
        if ($(this).val() !== "duplicate") {
            $("#js-duplicate-reports").addClass("hidden");
            return;
        } else {
            $("#js-duplicate-reports").removeClass("hidden");
        }
        // If this report is already marked as a duplicate of another, then
        // there's no need to refresh the list of duplicate reports
        var duplicate_of = $("#report_inspect_form [name=duplicate_of]").val();
        if (!!duplicate_of) {
            return;
        }
        var category = $("#report_inspect_form [name=category]").val();
        refresh_duplicate_list(undefined, {}, category);
    }

    function take_effect() {
        // We do not want to do anything if any other message is being shown
        if (document.getElementById('js-category-stopper')) {
            return false;
        }
        if ($('.js-responsibility-message:visible').length) {
            return false;
        }
        // On mobile only show once per category
        if ($('html').hasClass('mobile') && dismissed) {
            return false;
        }
        return true;
    }

    // Want to show potential duplicates when a regular user starts a new
    // report, or changes the category/location of a partial report.
    $(fixmystreet).on('report_new:category_change', refresh_duplicate_list);

    // Want to show duplicates when an inspector sets a report’s state to "duplicate".
    $(document).on('change.state', "#report_inspect_form select#state", inspect_form_state_change);

    // Also want to give inspectors a way to select a *new* duplicate report.
    $(document).on('click', "#js-change-duplicate-report", refresh_duplicate_list);

    $('.js-hide-duplicate-suggestions').on('click', function(e){
        e.preventDefault();
        fixmystreet.duplicates.hide();
    });

    fixmystreet.duplicates = {
        hide: function() {
            remove_duplicate_pins();
            remove_duplicate_list();
            dismissed = true;
        }
    };
})();
