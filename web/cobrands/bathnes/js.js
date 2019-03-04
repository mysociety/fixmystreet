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

fixmystreet.roadworks.filter = function(feature) {
  var category = $('select#form_category').val(),
      parts = feature.attributes.symbol.split(''),
      valid_types = ['h', 'n', 'l', 'w'],
      valid_subtypes = ['15', '25'],
      type = parts[2],
      sub_type = parts[4] + parts[5],
      categories = ['Damage to pavement', 'Damage to road', 'Faded road markings', 'Damaged Railing, manhole, or drain cover'];
    return OpenLayers.Util.indexOf(categories, category) != -1 &&
    ( OpenLayers.Util.indexOf(valid_types, type) != -1 ||
      ( type === 'o' && OpenLayers.Util.indexOf(valid_subtypes, sub_type) != -1 ) );
};

fixmystreet.roadworks.category_change = function() {
    if (fixmystreet.map) {
        fixmystreet.roadworks.show_nearby(null, fixmystreet.get_lonlat_from_dom());
    }
};

$(fixmystreet).on('report_new:category_change', fixmystreet.roadworks.category_change);

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
