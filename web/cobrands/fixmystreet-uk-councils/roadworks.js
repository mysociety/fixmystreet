/* Using this file, you also need to include the JavaScript file
 * OpenLayers.Projection.OrdnanceSurvey.js for the 27700 conversion, and an
 * OpenLayers build that includes OpenLayers.Layer.SphericalMercator and
 * OpenLayers.Format.GeoJSON.
 */

OpenLayers.Strategy.FixMyStreetRoadworks = OpenLayers.Class(OpenLayers.Strategy.BBOX, {
    // Only when we manually ask it to be updated
    activate: function() {
        var activated = OpenLayers.Strategy.prototype.activate.call(this);
        if(activated) {
            this.layer.events.on({
                "refresh": this.update,
                scope: this
            });
        }
        return activated;
    },

    CLASS_NAME: "OpenLayers.Strategy.FixMyStreetRoadworks"
});

(function(){

var tilma_host = fixmystreet.staging ? 'tilma.staging.mysociety.org' : 'tilma.mysociety.org';
var roadworks_defaults = {
    http_options: {
        url: "https://" + tilma_host + "/streetmanager.php"
    },
    srsName: "EPSG:27700",
    format_class: OpenLayers.Format.GeoJSON,
    strategy_class: OpenLayers.Strategy.FixMyStreetRoadworks,
    stylemap: fixmystreet.assets.stylemap_invisible,
    non_interactive: true,
    always_visible: true,
    nearest_radius: 100,
    road: true,
    name: "Street Manager",
    actions: {
        found: function(layer, feature) {
            if (fixmystreet.roadworks.filter(feature)) {
                fixmystreet.roadworks.display_message(feature);
                return true;
            } else {
                $(".js-roadworks-page").remove();
            }
        },
        not_found: function(layer) {
            $(".js-roadworks-page").remove();
        }
    }
};

fixmystreet.roadworks = {};

// fixmystreet.map.layers[5].getNearestFeature(new OpenLayers.Geometry.Point(-0.835614, 51.816562).transform(new OpenLayers.Projection("EPSG:4326"), new OpenLayers.Projection("EPSG:3857")), 10)

fixmystreet.roadworks.config = {};

fixmystreet.roadworks.display_message = function(feature) {
    var attr = feature.attributes,
        start = new Date(attr.start_date).toDateString(),
        end = new Date(attr.end_date).toDateString(),
        summary = attr.summary,
        desc = attr.description;

    var config = this.config,
        summary_heading_text = config.summary_heading_text || 'Summary',
        tag_top = config.tag_top || 'p',
        colon = config.colon ? ':' : '';

    var $msg = $('<div class="js-roadworks-message box-warning"><' + tag_top + '>Roadworks are scheduled near this location, so you may not need to report your issue.</' + tag_top + '></div>');
    var $dl = $("<dl></dl>").appendTo($msg);
    $dl.append("<dt>Dates" + colon + "</dt>");
    var $dates = $("<dd></dd>").appendTo($dl);
    $dates.text(start + " until " + end);
    if (config.extra_dates_text) {
        $dates.append('<br>' + config.extra_dates_text);
    }
    $dl.append("<dt>" + summary_heading_text + colon + "</dt>");
    $dl.append($("<dd></dd>").text(summary));
    if (desc) {
        $dl.append("<dt>Description" + colon + "</dt>");
        $dl.append($("<dd></dd>").text(desc));
    }
    if (attr.promoter) {
        $dl.append("<dt>Responsibility</dt>");
        $dl.append($("<dd></dd>").text(attr.promoter));
    }

    if (config.text_after) {
        $dl.append(config.text_after);
    }

    var $div = $(".js-reporting-page.js-roadworks-page");
    if (!$div.length || $div.data('workRef') !== attr.work_ref) {
        if (!$div.length) {
            $div = $("<div class='js-roadworks-page'></div>");
        }
        $div.data('workRef', attr.work_ref);
        $div.html($msg);
        fixmystreet.pageController.addNextPage('roadworks', $div);
    }
    var oxford_roadworks_page = $(".js-reporting-page.js-roadworks-oxf-page");
    var oxford_messages;
    if (oxford_roadworks_page.length) {
        oxford_messages = $(".js-oxf-roadworks-message");
    }
    if (oxford_messages) {
        oxford_roadworks_page.remove();
        $(".js-roadworks-message").after(oxford_messages);
    }
};

fixmystreet.roadworks.filter = function(feature) {
  var category = fixmystreet.reporting.selectedCategory().category,
        data = document.getElementById('roadworks-categories').dataset.roadworksCategories || '[]',
        categories = JSON.parse(data);
    return !categories.length || OpenLayers.Util.indexOf(categories, category) != -1;
};

var roadworks_layer = fixmystreet.assets.add(roadworks_defaults);

// Don't want to update it until they place a pin
fixmystreet.roadworks.update = function(){
    roadworks_layer.refresh({ force: true });
};

$(function(){
    if (fixmystreet.page === 'new') {
        fixmystreet.roadworks.update();
    }
});

})();
