/* Using this file, you also need to include the JavaScript file
 * OpenLayers.Projection.OrdnanceSurvey.js for the 27700 conversion, and an
 * OpenLayers build that includes OpenLayers.Layer.SphericalMercator and
 * OpenLayers.Format.GeoJSON.
 */

(function(){

var industry = { 'l': 4, 'n': 4, 'h': 4, 'e': 2, 't': 5, 'w': 6, 'g': 3, 'r': 17, 'm': 18, 'x': 19, 'p': 19 };
var industry_other = { '08': 7, '11': 19, '12': 8, '13': 14, '14': 12, '15': 20, '90': 4 };
var traffic_management = { 'n': 0, 'l': 1, 's': 2, 'p': 3, 'a': 4, 'r': 5, 'g': 6, 'c': 7 };
var impact = { 'g': 2, 'y': 1, 'r': 0 };

// 0-indexed
function getRow(symbol, promoter_org_ref) {
  if (promoter_org_ref == 7347) { return 24-1; }
  if (promoter_org_ref == 11 || promoter_org_ref == 15) { return 23-1; }
  var r = industry[symbol.substr(2, 1)] || industry_other[symbol.substr(4, 2)] || 4;
  return r-1;
}

// 0-indexed
function getColumn(symbol) {
  var tm = traffic_management[symbol.substr(3, 1)] || 0;
  if (symbol.substr(1, 1) == 'p') {
    return 28 + tm - 1;
  }
  return 1 + impact[symbol.substr(0, 1)] + tm * 3 - 1;
}

OpenLayers.Format.RoadworksForwardPlanning = OpenLayers.Class(OpenLayers.Format.GeoJSON, {
    read: function(json, type, filter) {
        type = (type) ? type : "FeatureCollection";
        var results = null;
        var obj = null;
        if (typeof json == "string") {
            obj = OpenLayers.Format.JSON.prototype.read.apply(this, [json, filter]);
        } else {
            obj = json;
        }
        if(!obj) {
            OpenLayers.Console.error("Bad JSON: " + json);
            return;
        }

        // Convert what we're given into GeoJSON
        var data = obj.query.data;
        obj = {
          'type': 'FeatureCollection',
          'features': []
        };
        for (var i = 0, l=data.longitude.length; i<l; i++) {
            var feature = {
              'id': data.se_id[i],
              'type': 'Feature',
              'properties': {
                'symbol': data.gsymbol_id[i],
                'symbol_num': getRow(data.gsymbol_id[i]) * 36 + getColumn(data.gsymbol_id[i]),
                'tooltip': data.tooltip[i],
                'org': data.org_name_disp[i],
                'promoter': data.promoter[i],
                'works_desc': data.works_desc[i],
                'start': data.start_date[i],
                'end': data.end_date[i],
              }
            };
            // var geojson = false;
            var geojson = data.geojson_wgs84[i];
            if (geojson) {
                feature.geometry = OpenLayers.Format.JSON.prototype.read.apply(this, [geojson]);
            } else {
                feature.geometry = {
                  'type': 'Point',
                  'coordinates': [data.longitude[i], data.latitude[i]]
                };
            }
            obj.features.push(feature);
        }
        return OpenLayers.Format.GeoJSON.prototype.read.apply(this, [obj, type, filter]);
    },

    CLASS_NAME: "OpenLayers.Format.RoadworksForwardPlanning"
});

// ---

function format_date(date) {
    var day = ('0' + date.getDate()).slice(-2);
    var month = ('0' + (date.getMonth() + 1)).slice(-2);
    var year = date.getFullYear();
    return day + '/' + month + '/' + year;
}

var stylemap = new OpenLayers.StyleMap({
    'default': new OpenLayers.Style({
        fillOpacity: 0,
        strokeOpacity: 0,
/*
        fillOpacity: 1,
        fillColor: "#FFFF00",
        strokeColor: "#000000",
        strokeOpacity: 0.8,
        strokeWidth: 2,
        pointRadius: 6,
        graphicWidth: 34,
        graphicHeight: 42,
        graphicXOffset: -17,
        graphicYOffset: -42,
        graphicOpacity: 1,
        externalGraphic: '/cobrands/fixmystreet-uk-councils/roadworks/${symbol_num}.png'
*/
    })
});

var roadworks_defaults = {
    http_options: {
        url: "https://portal.roadworks.org/data/",
        // url: "/data/",
        params: {
            get: 'Points',
            userid: '1',
            organisation_id: '', // Cobrand JS should extend and override this.
            filterimpact: '1,2,3,4',
            extended_func_id: '14',
        },
        filterToParams: function(filter, params) {
            params = params || {};
            filter.value.transform('EPSG:4326', 'EPSG:27700');
            params.b = filter.value.toArray();
            var date = new Date();
            params.filterstartdate = format_date(date);
            date.setMonth(date.getMonth() + 3);
            params.filterenddate = format_date(date);
            params.mapzoom = fixmystreet.map.getZoom() + fixmystreet.zoomOffset;
            return params;
        }
    },
    format_class: OpenLayers.Format.RoadworksForwardPlanning,
    strategy_class: OpenLayers.Strategy.FixMyStreet,
    stylemap: stylemap,
    body: "", // Cobrand JS should extend and override this.
    non_interactive: true,
    always_visible: true,
    nearest_radius: 100,
    road: true,
    all_categories: true,
    actions: {
        found: function(layer, feature) {
            $(".js-roadworks-message-" + layer.id).remove();
            if (!fixmystreet.roadworks.filter || fixmystreet.roadworks.filter(feature)) {
                fixmystreet.roadworks.display_message(feature);
                return true;
            }
        },
        not_found: function(layer) {
            $(".js-roadworks-message-" + layer.id).remove();
        }
    }
};

fixmystreet.roadworks = {};

fixmystreet.roadworks.layer_planned = $.extend(true, {}, roadworks_defaults, {
    http_options: { params: { t: 'fp' } }
});

fixmystreet.roadworks.layer_future = $.extend(true, {}, roadworks_defaults, {
    http_options: { params: { t: 'cw' } }
});

// fixmystreet.map.layers[5].getNearestFeature(new OpenLayers.Geometry.Point(-0.835614, 51.816562).transform(new OpenLayers.Projection("EPSG:4326"), new OpenLayers.Projection("EPSG:3857")), 10)

fixmystreet.roadworks.config = {};

fixmystreet.roadworks.display_message = function(feature) {
    var attr = feature.attributes,
        start = new Date(attr.start.replace(/{ts '([^ ]*).*/, '$1')).toDateString(),
        end = new Date(attr.end.replace(/{ts '([^ ]*).*/, '$1')).toDateString(),
        tooltip = attr.tooltip.replace(/\\n/g, '\n'),
        desc = attr.works_desc.replace(/\\n/g, '\n');

    var config = this.config,
        tag_top = config.tag_top || 'p',
        colon = config.colon ? ':' : '';

        var $msg = $('<div class="js-roadworks-message-' + feature.layer.id + ' box-warning"><' + tag_top + '>Roadworks are scheduled near this location, so you may not need to report your issue.</' + tag_top + '></div>');
        var $dl = $("<dl></dl>").appendTo($msg);
        $dl.append("<dt>Dates" + colon + "</dt>");
        $dl.append($("<dd></dd>").text(start + " until " + end));
        $dl.append("<dt>Summary" + colon + "</dt>");
        var $summary = $("<dd></dd>").appendTo($dl);
        tooltip.split("\n").forEach(function(para) {
            if (para.match(/^(\d{2}\s+\w{3}\s+(\d{2}:\d{2}\s+)?\d{4}( - )?){2}/)) {
                // skip showing the date again
                return;
            }
            if (config.skip_delays && para.match(/^delays/)) {
                // skip showing traffic delay information
                return;
            }
            $summary.append(para).append("<br />");
        });
        if (desc) {
            $dl.append("<dt>Description" + colon + "</dt>");
            $dl.append($("<dd></dd>").text(desc));
        }
        if (config.text_after) {
            $dl.append(config.text_after);
        }

    $msg.prependTo('#js-post-category-messages');
};

/* Stop sending a needless header so that no preflight CORS request */
OpenLayers.Request.XMLHttpRequest.prototype.setRequestHeader = function(sName, sValue) {
    if (sName.toLowerCase() == 'x-requested-with') {
        return;
    }
    if (!this._headers) {
        this._headers = {};
    }
    this._headers[sName] = sValue;
    return this._object.setRequestHeader(sName, sValue);
};

})();
