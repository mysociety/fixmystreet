(function(){

if (!fixmystreet.maps) {
    return;
}


OpenLayers.Format.EastSussex = OpenLayers.Class(OpenLayers.Format.JSON, {
    read: function(json, type, filter) {
        var obj = json;
        if (typeof json == "string") {
            obj = OpenLayers.Format.JSON.prototype.read.apply(this,
                                                              [json, filter]);
        }

        var results = [];
        for (var i=0, len=obj.length; i<len; i++) {
            var item = obj[i];
            var geom = new OpenLayers.Geometry.Point(item.Mid_Location__c.longitude, item.Mid_Location__c.latitude);
            var vec = new OpenLayers.Feature.Vector(geom, item);
            results.push(vec);
        }

        return results;
    },
    CLASS_NAME: "OpenLayers.Format.EastSussex"
});

OpenLayers.Protocol.EastSussex = OpenLayers.Class(OpenLayers.Protocol.HTTP, {
    read: function(options) {
        OpenLayers.Protocol.prototype.read.apply(this, arguments);
        options = options || {};
        options.params = OpenLayers.Util.applyDefaults(
            options.params, this.options.params);
        options = OpenLayers.Util.applyDefaults(options, this.options);
        var types = options.types.join('&types=');
        var coords = fixmystreet.map.getCenterWGS84();
        options.url = options.url + '?longitude=' + coords.lat + '&latitude=' + coords.lon + '&types=' + types;
        var resp = new OpenLayers.Protocol.Response({requestType: "read"});
        resp.priv = OpenLayers.Request.GET({
            url: options.url,
            callback: this.createCallback(this.handleRead, resp, options),
            params: options.params,
            headers: options.headers
        });
    },
    CLASS_NAME: "OpenLayers.Protocol.EastSussex"
});

var defaults = {
    http_options: {
      url: fixmystreet.staging ? "https://tilma.staging.mysociety.org/proxy/escc/" : "https://tilma.mysociety.org/proxy/escc/"
    },
    max_resolution: 1.194328566789627,
    geometryName: 'msGeometry',
    srsName: "EPSG:4326",
    body: "East Sussex County Council",
    format_class: OpenLayers.Format.EastSussex,
    protocol_class: OpenLayers.Protocol.EastSussex,
    asset_id_field: 'asset_id',
    attributes: {
      asset_id: 'id'
    }
};

fixmystreet.assets.add(defaults, {
    http_options: {
      types: [
        "Bollard", "Central Refuge Beacon", "External Illuminated Sign", "Floodlight", "Internal Illuminated Sign", "Lighting Column", "Reflect Bollard", "Safety bollards", "Solar Bollard", "Subway Unit", "Zebra X Beacon"
      ]
    },
    asset_item: 'street light',
    asset_category: ["Burning By Day", "Intermittent", "Lamp Dim", "Lamp Flashing", "Lamp Obscured", "Lamp Out", "Missing Number", "Noisy Column", "Vandalism" ],
    select_action: true,
    actions: {
        asset_found: function(asset) {
          var id = asset.attributes.Name || '';
          if (id !== '') {
              $('.category_meta_message').html('You have selected <b>' + id + '</b>');
          } else {
              $('.category_meta_message').html('You can pick a <b class="asset-spot">' + this.fixmystreet.asset_item + '</b> from the map &raquo;');
          }
        },
        asset_not_found: function() {
           $('.category_meta_message').html('You can pick a <b class="asset-spot">' + this.fixmystreet.asset_item + '</b> from the map &raquo;');
        }
    }
});

fixmystreet.assets.add(defaults, {
    http_options: {
      types: [
        "Grit bin"
      ]
    },
    asset_item: 'grit bin',
    asset_category: ["Broken Grit Bin", "Request For New Grit Bin", "Request To Refill Grit Bin"]
});

fixmystreet.assets.add(defaults, {
    http_options: {
      types: [
        "Filter Drain", "Gully and Catchpit"
      ]
    },
    asset_item: 'drain',
    asset_category: ["Blocked Drain", "Culvert", "Broken Drain Cover", "Smell", "Sunken Drain", "Missing Drain Cover"],
    select_action: true,
    actions: {
        asset_found: function(asset) {
          var last_clean = asset.attributes.Gully_Last_Clean_Date__c || '';
          var next_clean = asset.attributes.Gully_Next_Clean_Date__c || '';
          if (last_clean !== '' || next_clean !== '') {
              var message = '';
              if (last_clean) { message += '<b>Last Cleaned</b>: ' + last_clean; }
              if (next_clean) { message += ' <b>Next Clean</b>: ' + next_clean; }
              $('.category_meta_message').html(message);
          } else {
              $('.category_meta_message').html('You can pick a <b class="asset-spot">' + this.fixmystreet.asset_item + '</b> from the map &raquo;');
          }
        },
        asset_not_found: function() {
           $('.category_meta_message').html('You can pick a <b class="asset-spot">' + this.fixmystreet.asset_item + '</b> from the map &raquo;');
        }
    }
});

// can have multiple group
$(function(){
    $("#problem_form").on("change.category", function() {
        var group = '';
        if (OpenLayers.Util.indexOf(fixmystreet.bodies, 'East Sussex County Council') != -1 ) {
          group = $('#form_category :selected').parent().attr('label');
        }
        $('#form_group').val(group);
    });
});

})();
