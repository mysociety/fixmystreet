(function(){

if (!fixmystreet.maps) {
    return;
}

var host = fixmystreet.staging ? 'tilma.staging.mysociety.org' : 'tilma.mysociety.org';

var defaults = {
    http_wfs_url: "https://" + host + "/mapserver/highways",
    asset_type: 'area',
    // this covers zoomed right out on Cumbrian sections of
    // the M6
    max_resolution: 20,
    srsName: "EPSG:3857"
};

fixmystreet.assets.add(defaults, {
    wfs_feature: "Highways",
    stylemap: fixmystreet.assets.stylemap_invisible,
    always_visible: true,

    non_interactive: true,
    road: true,
    usrn: [
        {
            field: 'road_name',
            attribute: 'ROA_NUMBER'
        },
        {
            field: 'area_name',
            attribute: 'area_name'
        },
        {
            field: 'sect_label',
            attribute: 'sect_label'
        }
    ],
    // motorways are wide and the lines to define them are narrow so we
    // need a bit more margin for error in finding the nearest to stop
    // clicking in the middle of them being undetected
    nearest_radius: 15,
    actions: {
        found: function(layer, feature) {
            var highways_body_name = feature.attributes.ROA_NUMBER ? 'National Highways' : 'Traffic Scotland';
            var highways_body_cat_signifier = _set_body_cat_signifier(highways_body_name);
            var category = fixmystreet.reporting.selectedCategory().category;
            if (fixmystreet.assets.selectedFeature()) {
                $('.js-reporting-page--highways').remove();
                return;
            }
            var current_road_name = $('#highways strong').first().text();
            var new_road_name = highways_body_name === 'National Highways' ? feature.attributes.ROA_NUMBER : _scottish_road_name(feature.attributes.descriptor);
            if (current_road_name === new_road_name) {
                // this could be because of a category change, or because we've
                // received new data from the server (but the pin drop had
                // already shown the HE message)
                if ($('#js-highways:checked').length) {
                    if (category && !category.match(highways_body_cat_signifier)) {
                        he_council_litter_cat_selected(highways_body_name);
                    } else {
                        highways_body_selected(highways_body_name);
                    }
                } else {
                    non_highways_body_selected(highways_body_name);
                }
            } else {
                $('.js-reporting-page--highways').remove();
                add_highways_warning(new_road_name, highways_body_name);
            }
        },
        not_found: function(layer) {
            if (fixmystreet.body_overrides.get_only_send().match(/^(National Highways|Traffic Scotland)/)) {
                var match = fixmystreet.body_overrides.get_only_send().match(/^(National Highways|Traffic Scotland)/);
                highways_body_name = match[1];
                fixmystreet.body_overrides.remove_only_send();
                fixmystreet.body_overrides.do_not_send(highways_body_name);
            }
            $('.js-reporting-page--highways').remove();
        }
    }
});

function _set_body_cat_signifier(highways_body_name) {
    return highways_body_name === 'National Highways' ? 'NH' : 'TS';
}

function _scottish_road_name($descriptor) {
    major_road_regexp = new RegExp(/(^[A|M]\d+)(?:\(T\)|T)? /i);
    if (major_road_regexp.exec($descriptor)) {
        match = major_road_regexp.exec($descriptor);
        return match[1];
    } else {
        return $descriptor;
    }
}

function _update_category(input, highways_body_flag, highways_body_name) {
    var highways_body_cat_signifier = _set_body_cat_signifier(highways_body_name);
    var highways_categories = input.val().match(highways_body_cat_signifier);
    to_show = (highways_categories && highways_body_flag) || (!highways_categories && !highways_body_flag) || input.data(highways_body_cat_signifier.toLowerCase());
    input.parent().toggleClass('hidden-highways-choice', !to_show);
    return to_show ? 0 : 1;
}

function regenerate_category(highways_body_flag, highways_body_name) {
    if (!fixmystreet.reporting_data) return;

    if (highways_body_flag) {
        // We do not want to reenable the form if it has been disabled for
        // a non-highways category
        $('.js-reporting-page--next').prop('disabled', false);
    }

    // If we have come from NH site, the server has returned all the categories to show
    if (window.location.href.indexOf('&he_referral=1') != -1) {
        return;
    }

    $('#form_category_fieldset input').each(function() {
        var subcategory_id = $(this).data("subcategory");
        if (subcategory_id === undefined) {
            _update_category($(this), highways_body_flag, highways_body_name);
        } else {
            var $subcategory = $("#subcategory_" + subcategory_id);
            var hidden = 0;
            var inputs = $subcategory.find('input');
            inputs.each(function() {
                hidden += _update_category($(this), highways_body_flag, highways_body_name);
            });
            $(this).parent().toggleClass('hidden-highways-choice', hidden == inputs.length);
        }
    });

    // Also update any copies of subcategory inputs the category filter may have made
    document.querySelectorAll('.js-filter-subcategory input').forEach(function(input) {
        _update_category($(input), highways_body_flag, highways_body_name);
    });
}

function highways_body_selected(highways_body_name) {
    if (typeof highways_body_name !== 'string') {
        highways_body_name = highways_body_name.data.body_name;
    }
    fixmystreet.body_overrides.only_send(highways_body_name);
    fixmystreet.body_overrides.allow_send(highways_body_name);
    regenerate_category(true, highways_body_name);
    $(fixmystreet).trigger('report_new:highways_change');
    if (window.location.href.indexOf('&he_referral=1') != -1) {
        $('.js-reporting-page--next:visible').click();
        var message = "<div class='box-warning' id='national-highways-referral'>Please select the local council's most appropriate option for the litter or flytipping issue you would like to report.</div>";
        $('#js-top-message').append(message);
        $('.js-reporting-page--next').on('click', function() {
            $('#national-highways-referral').remove();
        });
    }
}

function he_council_litter_cat_selected(highways_body_name) {
    fixmystreet.body_overrides.remove_only_send();
    fixmystreet.body_overrides.do_not_send(highways_body_name);
    regenerate_category(true, highways_body_name); // DO want to keep NH top-level picked
    $(fixmystreet).trigger('report_new:highways_change');
}

function non_highways_body_selected(highways_body_name) {
    if (typeof highways_body_name !== 'string') {
        highways_body_name = highways_body_name.data.body_name;
    }
    fixmystreet.body_overrides.remove_only_send();
    fixmystreet.body_overrides.do_not_send(highways_body_name);
    regenerate_category(false, highways_body_name);
    $(fixmystreet).trigger('report_new:highways_change');
}

function add_highways_warning(road_name, highways_body_name) {
  var $warning = $('<div class="box-warning" id="highways"><p>It looks like you clicked on the <strong>' + road_name + '</strong> which is managed by <strong>' + highways_body_name + '</strong>. ' +
                   'Does your report concern something on this road, or somewhere else (e.g a road crossing it)?<p></div>');
  var $page = $('<div data-page-name="highwaysengland" class="js-reporting-page js-reporting-page--active js-reporting-page--highways"></div>');
  var $radios = $('<fiedset class="govuk-fieldset govuk-radios"></fieldset>');

    $('<div>')
        .addClass('govuk-radios__item')
        .append(
            $('<input>')
                .attr('type', 'radio')
                .attr('name', 'highways-choice')
                .attr('id', 'js-highways')
                .prop('checked', true)
                .on('click', {body_name: highways_body_name}, highways_body_selected)
                .addClass('govuk-radios__input'),
            $('<label>')
                .attr('for', 'js-highways')
                .text('On the ' + road_name)
                .addClass('govuk-label govuk-radios__label')
        )
        .appendTo($radios);

    $('<div>')
        .addClass('govuk-radios__item')
        .append(
            $('<input>')
                .attr('type', 'radio')
                .attr('name', 'highways-choice')
                .attr('id', 'js-not-highways')
                .on('click', {body_name: highways_body_name}, non_highways_body_selected)
                .addClass('govuk-radios__input'),
            $('<label>')
                .attr('for', 'js-not-highways')
                .text('Somewhere else')
                .addClass('govuk-label govuk-radios__label')
        )
        .appendTo($radios);

    $radios.appendTo($warning);
    $warning.wrap($page);
    $page = $warning.parent();
    $page.append('<button type="button" class="btn btn--block js-reporting-page--next" disabled>Continue</button>');

    $('.js-reporting-page').first().before($page);
    $page.nextAll('.js-reporting-page').removeClass('js-reporting-page--active');
    highways_body_selected(highways_body_name);
}

})();
