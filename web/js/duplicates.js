(function() {

    // Store a reference to the "duplicate" report pins so we can
    // quickly remove them when we’re finished showing duplicates.
    var current_duplicate_markers;

    // Report ID will be available on report inspect page,
    // but undefined on new report page.
    var report_id = $("#report_inspect_form .js-report-id").text() || undefined;

    function refresh_duplicate_list(evt, params) {
        if (params && params.skip_duplicates) {
            return;
        }

        // NOTE Category as fetched from #report_inspect_form will be in the
        // form 'group__category'.
        // Strictly speaking we should split this to get the bare category.
        // However, #report_inspect_form is used for an existing report (i.e.
        // there is a report_id), which means /nearby.json will be called,
        // which ignores the category here in favour of the one saved on the
        // report.
        var category = $("#report_inspect_form [name=category]").val() || fixmystreet.reporting.selectedCategory().category;

        // We check group also, in case that is provided in the config instead of subcat
        var group = fixmystreet.reporting.selectedCategory().group;

        if (!category) {
            return;
        }

        var nearby_url;
        var url_params = {
            filter_category: category,
            filter_group: group,
            latitude: $('input[name="latitude"]').val(),
            longitude: $('input[name="longitude"]').val()
        };

        if ( report_id ) {
            nearby_url = '/report/' + report_id + '/nearby.json';
            url_params.mode = 'inspector'; // Inspectors might want to see reports fairly far away (default 1000 metres)
            url_params.pin_size = 'small'; // How it's always been
        } else {
            nearby_url = '/around/nearby';
            url_params.mode = 'suggestions'; // Only want to bother public with very nearby reports (default 250 metres)
            url_params.pin_size = 'normal';
            url_params.bodies = JSON.stringify(fixmystreet.bodies);
        }

        if ($('html').hasClass('mobile')) {
            url_params.inline_maps = 1;
        }

        $.ajax({
            url: nearby_url,
            data: url_params,
            dataType: 'json'
        }).done(function(response) {
            if (response.pins.length) {
                render_duplicate_list(response);
            } else {
                remove_duplicate_list();
            }
        }).fail(function(){
            remove_duplicate_pins();
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

        $('#js-duplicate-reports').removeClass('js-reporting-page--skip');

        if (!fixmystreet.map.events.extensions.buttonclick.isDeviceTouchCapable) {
            // Highlight map pin when hovering associated list item.
            // (not on touchscreens though because a) the 'mouseenter' handler means
            // two taps are required on the 'read more' button - one to highlight
            // the list item and another to activate the button- and b) the pins
            // might be scrolled off the top of the screen anyway e.g. on phones)
            var timeout;
            $reports.on('mouseenter focusin', function(){
                var id = parseInt( $(this).data('reportId'), 10 );
                clearTimeout( timeout );
                fixmystreet.maps.markers_highlight( id );
            }).on('mouseleave focusout', function(){
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
                        $div.find('input[type="email"]').trigger('focus');
                    });
                    $li.find('.item-list__item--expandable__actions').slideUp(250);
                    $li.removeClass('js-expandable');
                    $li.addClass('item-list__item--selected');
                    $('.g-recaptcha').appendTo($div);
                });
                $li.find('.item-list__item--expandable__actions').append($button);
            });
            if (fixmystreet.markers) {
                current_duplicate_markers = fixmystreet.maps.markers_list( api_response.pins, true );
            }
        }
    }

    function render_duplicate_pins() {
        if ($('html').hasClass('mobile')) {
            return;
        }

        fixmystreet.markers.addFeatures( current_duplicate_markers );

        // Hide any asset layer that might be visible and get confused with the duplicates
        var layers = fixmystreet.map.getLayersBy('assets', true);
        for (var i = 0; i<layers.length; i++) {
            if (!layers[i].fixmystreet.always_visible && layers[i].getVisibility()) {
                layers[i].setVisibility(false);
            }
        }

        $(fixmystreet).trigger('maps:render_duplicates');
    }

    function remove_duplicate_list() {
        $('#js-duplicate-reports').addClass('js-reporting-page--skip');
    }

    function remove_duplicate_pins() {
        if ($('html').hasClass('mobile')) {
            return;
        }

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

        refresh_duplicate_list(undefined, {});
    }

    // Want to show potential duplicates when a regular user starts a new
    // report, or changes the category/location of a partial report.
    $(fixmystreet).on('report_new:category_change', refresh_duplicate_list);

    // Want to show duplicates when an inspector sets a report’s state to "duplicate".
    $(document).on('change.state', "#report_inspect_form select#state", inspect_form_state_change);

    // Also want to give inspectors a way to select a *new* duplicate report.
    $(document).on('click', "#js-change-duplicate-report", refresh_duplicate_list);

    if ( $('#problem_form').length ) {
        $('#js-duplicate-reports').removeClass('hidden'); // Handled by page code
    }

    $(fixmystreet).on('report_new:page_change', function(e, $from, $to) {
        if ($to.hasClass('js-reporting-page--duplicates')) {
            render_duplicate_pins();
        }
        if ($from.hasClass('js-reporting-page--duplicates')) {
            remove_duplicate_pins();
        }
    });

})();
