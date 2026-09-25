/*
    Similar to web/cobrands/highways/assets.js (vs web/cobrands/highwaysengland/assets.js),
    this file is for handling canals on fixmystreet.com and other cobrands that
    aren't Canal & River Trust (vs web/cobrands/canalrivertrust/assets.js).
*/

(function(){

if (!fixmystreet.maps) {
    return;
}

var body_name = 'Canal & River Trust';

var host = fixmystreet.staging ? 'tilma.staging.mysociety.org' : 'tilma.mysociety.org';

var defaults = {
    http_wfs_url: "https://" + host + "/mapserver/crt",
    asset_type: 'area',
    // this covers zoomed right out on Cumbrian sections of
    // the M6
    max_resolution: 20,
    srsName: "EPSG:3857"
};

fixmystreet.assets.add(defaults, {
    wfs_feature: "Canals",
    name: "canals",
    stylemap: fixmystreet.assets.stylemap_invisible,
    always_visible: true,

    non_interactive: true,
    road: true,

    // canals are wide and the lines to define them are narrow so we
    // need a bit more margin for error in finding the nearest to stop
    // clicking in the middle of them being undetected
    nearest_radius: 20,
    actions: {
        found: function(layer, feature) {
            fixmystreet.highways_canals.canals_layer_queried = true;
            fixmystreet.highways_canals.canals_asset_selected = true;

            // 'Somewhere else' option selected from canal question,
            // so we either go to highways question or show standard
            // categories
            if (fixmystreet.highways_canals.canals_somewhere_else) {
                return;
            }

            if (fixmystreet.assets.selectedFeature()) {
                $('.js-reporting-page--canals').remove();
                return;
            }

            var current_canal_name = $('#canals strong').first().text();

            var new_canal_name = feature.attributes.name;

            if (current_canal_name === new_canal_name) {
                // this could be because of a category change, or because we've
                // received new data from the server (but the pin drop had
                // already shown the CRT message)
                if ($('#js-canals:checked').length) {
                    canal_selected();
                } else {
                    non_canal_selected();
                }
            } else {
                $('.js-reporting-page--canals').remove();
                add_canals_warning(new_canal_name);
            }
        },
        not_found: function(layer) {
            fixmystreet.highways_canals.canals_layer_queried = true;

            if (fixmystreet.body_overrides.get_only_send() === body_name) {
                fixmystreet.body_overrides.remove_only_send();
                fixmystreet.body_overrides.do_not_send(body_name);
            }
            $('.js-reporting-page--canals').remove();
            if (!$('.js-reporting-page--active').length) {
                $('.js-reporting-page').first().addClass('js-reporting-page--active');
            }
        }
    }
});

function add_canals_warning(canal_name) {
    var $warning = $(
        '<div class="box-warning" id="canals"><p>It looks like you clicked on <strong>' +
        canal_name +
        '</strong> which is managed by <strong>' +
        body_name +
        '</strong>. ' +
        'Does your report concern something on this canal, or somewhere else (e.g a road crossing it)?<p></div>'
    );

    var $page = $('<div data-page-name="canalrivertrust" class="js-reporting-page js-reporting-page--active js-reporting-page--canals"></div>');
    var $radios = $('<fieldset class="govuk-fieldset govuk-radios"></fieldset>');

    $('<div>')
        .addClass('govuk-radios__item')
        .append(
            $('<input>')
                .attr('type', 'radio')
                .attr('name', 'canals-choice')
                .attr('id', 'js-canals')
                .prop('checked', true)
                .on('click', {body_name: body_name}, canal_selected)
                .addClass('govuk-radios__input'),
            $('<label>')
                .attr('for', 'js-canals')
                .text('On the ' + canal_name)
                .addClass('govuk-label govuk-radios__label')
        )
        .appendTo($radios);

    $('<div>')
        .addClass('govuk-radios__item')
        .append(
            $('<input>')
                .attr('type', 'radio')
                .attr('name', 'canals-choice')
                .attr('id', 'js-not-canals')
                .on('click', {body_name: body_name}, non_canal_selected)
                .addClass('govuk-radios__input'),
            $('<label>')
                .attr('for', 'js-not-canals')
                .text('Somewhere else')
                .addClass('govuk-label govuk-radios__label')
        )
        .appendTo($radios);

    $radios.appendTo($warning);
    $warning.wrap($page);
    $page = $warning.parent();

    var $button = $('<button type="button" class="btn btn--block js-reporting-page--next">Continue</button>');
    $button.on('click', display_next);
    $page.append($button);

    $('.js-reporting-page').first().before($page);
    $page.nextAll('.js-reporting-page').removeClass('js-reporting-page--active');
}

// Shows canal categories if 'On <canal>' selected (set in canal_selected()).
// Otherwise, if we are also on a highway,
// goes to the highway display code.
// Otherwise, shows standard categories (set in non_canal_selected()).
function display_next() {
    var canals_selected = $('#js-canals:checked').length;

    fixmystreet.highways_canals.canals_somewhere_else = canals_selected ? false : true;

    // 'Somewhere else' selected; go to highways question if appropriate
    if (fixmystreet.highways_canals.canals_somewhere_else) {
        if (fixmystreet.highways_canals.highways_asset_selected) {
            var highways_layer = fixmystreet.map.getLayersByName('highways')[0];

            highways_layer.fixmystreet.actions.found(highways_layer, highways_layer.selected_feature);
        }
    }
}

function canal_selected() {
    fixmystreet.body_overrides.only_send(body_name);
    fixmystreet.body_overrides.allow_send(body_name);

    regenerate_category(true);
}

function non_canal_selected() {
    fixmystreet.body_overrides.remove_only_send();
    fixmystreet.body_overrides.do_not_send(body_name);

    regenerate_category(false);
}

function regenerate_category(canals_body_flag) {
    if (!fixmystreet.reporting_data) return;

    $('#form_category_fieldset input').each(function() {
        var subcategory_id = $(this).data("subcategory");
        if (subcategory_id === undefined) {
            _update_category($(this), canals_body_flag);
        } else {
            var $subcategory = $("#subcategory_" + subcategory_id);
            var hidden = 0;
            var inputs = $subcategory.find('input');
            inputs.each(function() {
                hidden += _update_category($(this), canals_body_flag);
            });

            $(this).parent().toggleClass('hidden-canals-choice', hidden == inputs.length);
        }
    });

    // Also update any copies of subcategory inputs the category filter may have made
    document.querySelectorAll('.js-filter-subcategory input').forEach(function(input) {
        _update_category($(input), canals_body_flag);
    });
}

function _update_category(input, canals_body_flag) {
    var canals_cat_signifier = 'CRT';
    var canals_categories = input.val().match(canals_cat_signifier);
    to_show = (canals_categories && canals_body_flag) ||
        (!canals_categories && !canals_body_flag) ||
        input.data(canals_cat_signifier.toLowerCase());
    input.parent().toggleClass('hidden-canals-choice', !to_show);
    return to_show ? 0 : 1;
}

})();
