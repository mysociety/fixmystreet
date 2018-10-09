(function(){

if (!fixmystreet.maps) {
    return;
}

fixmystreet.roadworks.display_message = function(feature) {
    var attr = feature.attributes,
        start = new Date(attr.start.replace(/{ts '([^ ]*).*/, '$1')).toDateString(),
        end = new Date(attr.end.replace(/{ts '([^ ]*).*/, '$1')).toDateString(),
        tooltip = attr.tooltip.replace(/\\n/g, '\n'),
        desc = attr.works_desc.replace(/\\n/g, '\n');

        var $msg = $('<div class="js-roadworks-message box-warning"><h3>Roadworks are scheduled near this location, so you may not need to report your issue.</h3></div>');
        var $dl = $("<dl></dl>").appendTo($msg);
        $dl.append("<dt>Dates:</dt>");
        $dl.append($("<dd></dd>").text(start + " until " + end));
        $dl.append("<dt>Summary:</dt>");
        var $summary = $("<dd></dd>").appendTo($dl);
        tooltip.split("\n").forEach(function(para) {
            if (para.match(/^(\d{2}\s+\w{3}\s+(\d{2}:\d{2}\s+)?\d{4}( - )?){2}/)) {
                // skip showing the date again
                return;
            }
            if (para.match(/^delays/)) {
                // skip showing traffic delay information
                return;
            }
            $summary.append(para).append("<br />");
        });
        if (desc) {
            $dl.append("<dt>Description:</dt>");
            $dl.append($("<dd></dd>").text(desc));
        }
        $dl.append($("<p>If you think this issue needs immediate attention you can continue your report below</p>"));

        $('.change_location').after($msg);
};

var org_id = '114';
var body = "Bath and North East Somerset Council";
fixmystreet.assets.add($.extend(true, {}, fixmystreet.roadworks.layer_future, {
    http_options: { params: { organisation_id: org_id } },
    body: body
}));
fixmystreet.assets.add($.extend(true, {}, fixmystreet.roadworks.layer_planned, {
    http_options: { params: { organisation_id: org_id } },
    body: body
}));

})();
