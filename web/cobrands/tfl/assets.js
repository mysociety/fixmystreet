(function(){

if (!fixmystreet.maps) {
    return;
}

var defaults = {
    http_options: {
        url: "https://tilma.staging.mysociety.org/mapserver/tfl",
        params: {
            SERVICE: "WFS",
            VERSION: "1.1.0",
            REQUEST: "GetFeature",
            SRSNAME: "urn:ogc:def:crs:EPSG::3857"
        }
    },
    asset_type: 'spot',
    max_resolution: 2.388657133579254,
    min_resolution: 0.5971642833948135,
    geometryName: 'msGeometry',
    srsName: "EPSG:3857",
    strategy_class: OpenLayers.Strategy.FixMyStreet,
    body: "TfL"
};

var asset_defaults = $.extend(true, {}, defaults, {
    select_action: true,
    no_asset_msg_id: '#js-not-an-asset',
    actions: {
        asset_found: function() {
            fixmystreet.message_controller.asset_found();
        },
        asset_not_found: function() {
            fixmystreet.message_controller.asset_not_found(this);
        }
    }
});

fixmystreet.assets.add(asset_defaults, {
    http_options: {
        params: {
            TYPENAME: "trafficsignals"
        }
    },
    asset_id_field: 'Site',
    attributes: {
        site: 'Site',
    },
    asset_group: "Traffic Lights",
    asset_item: 'traffic signal'
});

fixmystreet.assets.add(asset_defaults, {
    http_options: {
        params: {
            TYPENAME: "busstops"
        }
    },
    asset_id_field: 'STOP_CODE',
    attributes: {
        stop_code: 'STOP_CODE',
    },
    asset_group: "Bus Stops and Shelters",
    asset_item: 'bus stop'
});

/* Roadworks.org asset layer */

var org_id = '1250';
var body = "TfL";

var rw_stylemap = new OpenLayers.StyleMap({
    'default': new OpenLayers.Style({
        fillOpacity: 1,
        fillColor: "#FFFF00",
        strokeColor: "#000000",
        strokeOpacity: 0.8,
        strokeWidth: 2,
        pointRadius: 6,
        graphicWidth: 34,
        graphicHeight: 38,
        graphicXOffset: -17,
        graphicYOffset: -38,
        graphicOpacity: 1,
        externalGraphic: '/cobrands/tfl/roadworks.png'
    }),
    'hover': new OpenLayers.Style({
        fillColor: "#55BB00",
        externalGraphic: '/cobrands/tfl/roadworks-green.png'
    }),
    'select': new OpenLayers.Style({
        fillColor: "#55BB00",
        externalGraphic: '/cobrands/tfl/roadworks-green.png'
    })
});

OpenLayers.Format.TfLRoadworksOrg = OpenLayers.Class(OpenLayers.Format.RoadworksOrg, {
    endMonths: 0,
    convertToPoints: true,
    CLASS_NAME: "OpenLayers.Format.TfLRoadworksOrg"
});

fixmystreet.assets.add(fixmystreet.roadworks.layer_future, {
    http_options: {
        params: { organisation_id: org_id },
    },
    format_class: OpenLayers.Format.TfLRoadworksOrg,
    body: body,
    non_interactive: false,
    always_visible: false,
    road: false,
    all_categories: false,
    actions: null,
    asset_category: "Roadworks",
    stylemap: rw_stylemap,
    asset_id_field: 'promoter_works_ref',
    asset_item: 'roadworks',
    attributes: {
        promoter_works_ref: 'promoter_works_ref',
        start: 'start',
        end: 'end',
        promoter: 'promoter',
        works_desc: 'works_desc',
        works_state: function(feature) {
            return {
                1: "1", // Haven't seen this in the wild yet
                2: "Advanced planning",
                3: "Planned work about to start",
                4: "Work in progress"
            }[this.attributes.works_state] || this.attributes.works_state;
        },
        tooltip: 'tooltip'
    }
});


})();
