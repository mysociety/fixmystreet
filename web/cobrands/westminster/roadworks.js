(function(){

if (!fixmystreet.maps) {
    return;
}

var org_id = '1160';
var body = "Westminster City Council";
fixmystreet.assets.add(fixmystreet.roadworks.layer_future, {
    http_options: { params: { organisation_id: org_id } },
    body: body
});
fixmystreet.assets.add(fixmystreet.roadworks.layer_planned, {
    http_options: { params: { organisation_id: org_id } },
    body: body
});

// Westminster want to also display the responsible party in roadworks messages
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
