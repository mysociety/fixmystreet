(function(){

if (!fixmystreet.maps) {
    return;
}

var defaults = {
    http_options: {
        url: "https://tilma.mysociety.org/mapserver/highways",
        params: {
            SERVICE: "WFS",
            VERSION: "1.1.0",
            REQUEST: "GetFeature",
            SRSNAME: "urn:ogc:def:crs:EPSG::3857"
        }
    },
    asset_type: 'area',
    // this covers zoomed right out on Cumbrian sections of
    // the M6
    max_resolution: 20,
    srsName: "EPSG:900913",
    strategy_class: OpenLayers.Strategy.FixMyStreet
};

fixmystreet.assets.add(defaults, {
    http_options: {
        params: {
            TYPENAME: "Highways"
        }
    },
    stylemap: fixmystreet.assets.stylemap_invisible,
    always_visible: true,

    non_interactive: true,
    road: true,
    all_categories: true,
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
            if (fixmystreet.assets.selectedFeature()) {
                $('#highways').remove();
                return;
            }
            var current_road_name = $('#highways strong').first().text();
            var new_road_name = feature.attributes.ROA_NUMBER;
            if (current_road_name === new_road_name) {
                // this could be because of a category change, or because we've
                // received new data from the server (but the pin drop had
                // already shown the HE message)
                if ($('#js-highways:checked').length) {
                    he_selected();
                } else {
                    non_he_selected();
                }
            } else {
                $('#highways').remove();
                add_highways_warning(new_road_name);
            }
        },
        not_found: function(layer) {
            if (fixmystreet.body_overrides.get_only_send() === 'Highways England') {
                fixmystreet.body_overrides.remove_only_send();
                fixmystreet.body_overrides.do_not_send('Highways England');
            }
            $('#highways').remove();
        }
    }
});

function regenerate_category(he_flag) {
    if (!fixmystreet.reporting_data) return;

    var old_category = $("#form_category").val();

    // Restart the category dropdown from the original data (not all of it as
    // we keep subcategories the same)
    var select = $(fixmystreet.reporting_data.category).filter('select');
    if (he_flag) {
        var select1 = select.find('> option:first-child')[0].outerHTML;
        var select2 = select.find('optgroup[label*="Highways England"]').html();
        $('#form_category').html(select1 + select2);
    } else {
        select.find('optgroup[label*="Highways England"]').remove();
        select = select.html();
        $('#form_category').html(select);
    }
    if ($("#form_category option[value=\"" + old_category + "\"]").length) {
        $("#form_category").val(old_category);
    }

    // Recalculate the category groups
    var old_category_group = $('#category_group').val() || $('#filter_group').val();
    $('#category_group').remove();
    fixmystreet.set_up.category_groups(old_category_group, true);
}

function he_selected() {
    fixmystreet.body_overrides.only_send('Highways England');
    fixmystreet.body_overrides.allow_send('Highways England');
    regenerate_category(true);
    $(fixmystreet).trigger('report_new:highways_change');
}

function non_he_selected() {
    fixmystreet.body_overrides.remove_only_send();
    fixmystreet.body_overrides.do_not_send('Highways England');
    regenerate_category(false);
    $(fixmystreet).trigger('report_new:highways_change');
}

function add_highways_warning(road_name) {
  var $warning = $('<div class="box-warning" id="highways"><p>It looks like you clicked on the <strong>' + road_name + '</strong> which is managed by <strong>Highways England</strong>. ' +
                   'Does your report concern something on this road, or somewhere else (e.g a road crossing it)?<p></div>');
  var $radios = $('<p class="segmented-control segmented-control--radio"></p>');

    $('<input>')
        .attr('type', 'radio')
        .attr('name', 'highways-choice')
        .attr('id', 'js-highways')
        .prop('checked', true)
        .on('click', he_selected)
        .appendTo($radios);
    $('<label>')
        .attr('for', 'js-highways')
        .text('On the ' + road_name)
        .addClass('btn')
        .appendTo($radios);
    $('<input>')
        .attr('type', 'radio')
        .attr('name', 'highways-choice')
        .attr('id', 'js-not-highways')
        .on('click', non_he_selected)
        .appendTo($radios);
    $('<label>')
        .attr('for', 'js-not-highways')
        .text('Somewhere else')
        .addClass('btn')
        .appendTo($radios);
    $radios.appendTo($warning);
    $('.change_location').after($warning);
    he_selected();
}

})();
