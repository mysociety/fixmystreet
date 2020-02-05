(function(){

translation_strings.name.validName = 'Please enter your full name, Transport for London needs this information – if you do not wish your name to be shown on the site, untick the box below';
translation_strings.incident_date = { date: 'Enter a date in the format dd/mm/yyyy' };
translation_strings.time = 'Enter a time in the format hh:mm';

if (jQuery.validator) {
    jQuery.validator.addMethod('time', function(value, element) {
        return this.optional(element) || /^([0-9]|0[0-9]|1[0-9]|2[0-3]):[0-5][0-9]$/.test( value );
    }, translation_strings.time );
}

fixmystreet.tfl_link_update = function() {
    var lat = document.getElementById('fixmystreet.latitude');
    if (!lat) {
        return;
    }
    lat = lat.value;
    var lon = document.getElementById('fixmystreet.longitude').value;
    $('.js-not-tfl-link').each(function(){
        this.search = 'latitude=' + lat + '&longitude=' + lon;
    });
};
$(fixmystreet).on('maps:update_pin', fixmystreet.tfl_link_update);
$(fixmystreet).on('report_new:category_change', fixmystreet.tfl_link_update);

$(function() {
    function update_category_group_label() {
        var group = $("#report_inspect_form select#category option:selected").closest("optgroup").attr('label');
        var $label = $("#report_inspect_form select#category").closest("p").find("label");
        if (group) {
            $label.text("Category (" + group + ")");
        } else {
            $label.text("Category");
        }
    }
    $(document).on('change', "#report_inspect_form select#category", update_category_group_label);
    $(fixmystreet).on('display:report', update_category_group_label);
    update_category_group_label();
});

})();

OpenLayers.Layer.TLRN = OpenLayers.Class(OpenLayers.Layer.XYZ, {
    name: 'TLRN',
    url: [
        "//tilma.mysociety.org/tlrn/${z}/${x}/${y}.png",
        "//a.tilma.mysociety.org/tlrn/${z}/${x}/${y}.png",
        "//b.tilma.mysociety.org/tlrn/${z}/${x}/${y}.png",
        "//c.tilma.mysociety.org/tlrn/${z}/${x}/${y}.png"
    ],
    sphericalMercator: true,
    isBaseLayer: false,
    CLASS_NAME: "OpenLayers.Layer.TLRN"
});

$(function() {
    if (!fixmystreet.map) {
        return;
    }

    // Can't use vector layer on reports, too big, use tiles instead
    if (fixmystreet.page === 'reports') {
        var layer = new OpenLayers.Layer.TLRN();
        fixmystreet.map.addLayer(layer);
        layer.setVisibility(true);
        var pins_layer = fixmystreet.map.getLayersByName("Pins")[0];
        if (pins_layer) {
            layer.setZIndex(pins_layer.getZIndex()-1);
        }
    }
});
