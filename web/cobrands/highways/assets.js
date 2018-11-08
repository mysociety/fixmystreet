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
    format_class: OpenLayers.Format.GML.v3.MultiCurveFix,
    asset_type: 'area',
    // this covers zoomed right out on Cumbrian sections of
    // the M6
    max_resolution: 20,
    min_resolution: 0.5971642833948135,
    srsName: "EPSG:900913",
    strategy_class: OpenLayers.Strategy.FixMyStreet
};

var highways_stylemap = new OpenLayers.StyleMap({
    'default': new OpenLayers.Style({
        fill: false,
        stroke: false,
    })
});

fixmystreet.assets.add($.extend(true, {}, defaults, {
    http_options: {
        params: {
            TYPENAME: "Highways"
        }
    },
    stylemap: highways_stylemap,
    always_visible: true,

    non_interactive: true,
    road: true,
    all_categories: true,
    // motorways are wide and the lines to define them are narrow so we
    // need a bit more margin for error in finding the nearest to stop
    // clicking in the middle of them being undetected
    nearest_radius: 15,
    actions: {
        found: function(layer, feature) {
            // if we've changed location then we want to reset things otherwise
            // this is probably just being called again by a category change
            var lat = $('#fixmystreet\\.latitude').val(),
                lon = $('#fixmystreet\\.longitude').val();
            if ( fixmystreet.body_overrides.location &&
                 lat == fixmystreet.body_overrides.location.latitude &&
                 lon == fixmystreet.body_overrides.location.longitude ) {
                return;
            }
            $('#highways').remove();
            if ( !fixmystreet.assets.selectedFeature() ) {
                fixmystreet.body_overrides.only_send('Highways England');
                add_highways_warning(feature.attributes.ROA_NUMBER);
            }
        },
        not_found: function(layer) {
            fixmystreet.body_overrides.location = null;
            if (fixmystreet.body_overrides.get_only_send() === 'Highways England') {
                fixmystreet.body_overrides.remove_only_send();
            }
            $('#highways').remove();
        }
    }
}));

function add_highways_warning(road_name) {
  var $warning = $('<div class="box-warning" id="highways"><p>It looks like you clicked on the <strong>' + road_name + '</strong> which is managed by <strong>Highways England</strong>. ' +
                   'Does your report concern something on this road, or somewhere else (e.g a road crossing it)?<p></div>');
  var $radios = $('<p class="segmented-control segmented-control--radio"></p>');

    $('<input>')
        .attr('type', 'radio')
        .attr('name', 'highways-choice')
        .attr('id', 'js-highways')
        .prop('checked', true)
        .on('click', function() {
            fixmystreet.body_overrides.location = null;
            fixmystreet.body_overrides.only_send('Highways England');
            $(fixmystreet).trigger('report_new:highways_change');
        })
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
        .on('click', function() {
            fixmystreet.body_overrides.location = {
                latitude: $('#fixmystreet\\.latitude').val(),
                longitude: $('#fixmystreet\\.longitude').val()
            };
            fixmystreet.body_overrides.remove_only_send();
            $(fixmystreet).trigger('report_new:highways_change');
        })
        .appendTo($radios);
    $('<label>')
        .attr('for', 'js-not-highways')
        .text('Somewhere else')
        .addClass('btn')
        .appendTo($radios);
    $radios.appendTo($warning);
    $('.change_location').after($warning);
    fixmystreet.body_overrides.location = null;
    fixmystreet.body_overrides.only_send('Highways England');
    $(fixmystreet).trigger('report_new:highways_change');
}

})();
