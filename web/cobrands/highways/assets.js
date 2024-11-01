(function(){

if (!fixmystreet.maps) {
    return;
}

var defaults = {
    http_wfs_url: "https://tilma.mysociety.org/mapserver/highways",
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
            var category = fixmystreet.reporting.selectedCategory().category;
            if (fixmystreet.assets.selectedFeature()) {
                $('.js-reporting-page--highways').remove();
                return;
            }
            var current_road_name = $('#highways strong').first().text();
            var new_road_name = feature.attributes.ROA_NUMBER;
            if (current_road_name === new_road_name) {
                // this could be because of a category change, or because we've
                // received new data from the server (but the pin drop had
                // already shown the HE message)
                if ($('#js-highways:checked').length) {
                    if (category && !category.match('NH')) {
                        he_council_litter_cat_selected();
                    } else {
                        he_selected();
                    }
                } else {
                    non_he_selected();
                }
            } else {
                $('.js-reporting-page--highways').remove();
                add_highways_warning(new_road_name);
            }
        },
        not_found: function(layer) {
            if (fixmystreet.body_overrides.get_only_send() === 'National Highways') {
                fixmystreet.body_overrides.remove_only_send();
                fixmystreet.body_overrides.do_not_send('National Highways');
            }
            $('.js-reporting-page--highways').remove();
        }
    }
});

function _update_category(input, he_flag) {
    var nh = input.val().match('NH');
    to_show = (nh && he_flag) || (!nh && !he_flag) || input.data('nh');
    input.parent().toggleClass('hidden-highways-choice', !to_show);
    return to_show ? 0 : 1;
}

function regenerate_category(he_flag) {
    if (!fixmystreet.reporting_data) return;

    if (he_flag) {
        // We do not want to reenable the form if it has been disabled for
        // a non-NH category
        $('.js-reporting-page--next').prop('disabled', false);
    }

    // If we have come from NH site, the server has returned all the categories to show
    if (window.location.href.indexOf('&he_referral=1') != -1) {
        return;
    }

    $('#form_category_fieldset input').each(function() {
        var subcategory_id = $(this).data("subcategory");
        if (subcategory_id === undefined) {
            _update_category($(this), he_flag);
        } else {
            var $subcategory = $("#subcategory_" + subcategory_id);
            var hidden = 0;
            var inputs = $subcategory.find('input');
            inputs.each(function() {
                hidden += _update_category($(this), he_flag);
            });
            $(this).parent().toggleClass('hidden-highways-choice', hidden == inputs.length);
        }
    });

    // Also update any copies of subcategory inputs the category filter may have made
    document.querySelectorAll('.js-filter-subcategory input').forEach(function(input) {
        _update_category($(input), he_flag);
    });
}

function he_selected() {
    fixmystreet.body_overrides.only_send('National Highways');
    fixmystreet.body_overrides.allow_send('National Highways');
    regenerate_category(true);
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

function he_council_litter_cat_selected() {
    fixmystreet.body_overrides.remove_only_send();
    fixmystreet.body_overrides.do_not_send('National Highways');
    regenerate_category(true); // DO want to keep NH top-level picked
    $(fixmystreet).trigger('report_new:highways_change');
}

function non_he_selected() {
    fixmystreet.body_overrides.remove_only_send();
    fixmystreet.body_overrides.do_not_send('National Highways');
    regenerate_category(false);
    $(fixmystreet).trigger('report_new:highways_change');
}

function add_highways_warning(road_name) {
  var $warning = $('<div class="box-warning" id="highways"><p>It looks like you clicked on the <strong>' + road_name + '</strong> which is managed by <strong>National Highways</strong>. ' +
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
                .on('click', he_selected)
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
                .on('click', non_he_selected)
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
    he_selected();
}

})();
