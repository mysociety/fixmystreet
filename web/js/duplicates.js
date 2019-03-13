(function() {

    // Store a reference to the "duplicate" report pins so we can
    // quickly remove them when we’re finished showing duplicates.
    var current_duplicate_markers;

    // Report ID will be available on report inspect page,
    // but undefined on new report page.
    var report_id = $("#report_inspect_form .js-report-id").text() || undefined;

    function refresh_duplicate_list() {
        var category = $('select[name="category"]').val();
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

        $.ajax({
            url: nearby_url,
            data: url_params,
            dataType: 'json'
        }).done(function(response) {
            if ( response.pins.length ){
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

        $('#js-duplicate-reports').hide().removeClass('hidden').slideDown();
        if ( $('#problem_form').length ) {
            $('.js-hide-if-invalid-category').slideUp();
        }

        // Highlight map pin when hovering associated list item.
        var timeout;
        $reports.on('mouseenter', function(){
            var id = parseInt( $(this).data('reportId'), 10 );
            clearTimeout( timeout );
            fixmystreet.maps.markers_highlight( id );
        }).on('mouseleave', function(){
            timeout = setTimeout( fixmystreet.maps.markers_highlight, 50 );
        });

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
        var markers = fixmystreet.maps.markers_list( api_response.pins, true );
        fixmystreet.markers.removeFeatures( current_duplicate_markers );
        fixmystreet.markers.addFeatures( markers );
        current_duplicate_markers = markers;
    }

    function remove_duplicate_list(cb) {
        var animations = [];

        animations.push( $.Deferred() );
        $('#js-duplicate-reports').slideUp(function(){
            $(this).addClass('hidden');
            $(this).find('ul').empty();
            animations[0].resolve();
        });
        if ( $('#problem_form').length ) {
            animations.push( $.Deferred() );
            $('.js-hide-if-invalid-category').slideDown(function(){
                animations[1].resolve();
            });
        }

        $.when.apply(this, animations).then(cb);
    }

    function remove_duplicate_pins() {
        fixmystreet.markers.removeFeatures( current_duplicate_markers );
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
        refresh_duplicate_list();
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
        remove_duplicate_pins();
        remove_duplicate_list(function(){
            $('#form_title').focus();
        });
    });

})();
