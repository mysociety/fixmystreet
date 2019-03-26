(function(){

if (!fixmystreet.maps) {
    return;
}

fixmystreet.assets.add($.extend(true, {}, fixmystreet.roadworks.layer_future, {
    http_options: { params: { organisation_id: '1070' } },
    body: "Lincolnshire County Council"
}));
// NB Lincs don't want forward planning works displayed, so
// fixmystreet.roadworks.layer_planned is deliberately missing here.


// Lincs want to also display the responsible party in roadworks messages
var original_display_message = fixmystreet.roadworks.display_message;
fixmystreet.roadworks.display_message = function(feature) {
    var retval = original_display_message.apply(this, arguments);

    if (feature.attributes.promoter) {
        var $dl = $(".js-roadworks-message-" + feature.layer.id + " dl");
        $dl.append("<dt>Responsibility</dt>");
        $dl.append($("<dd></dd>").text(feature.attributes.promoter));
    }

    return retval;
};

})();
