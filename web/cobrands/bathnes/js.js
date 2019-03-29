(function(){

if (!fixmystreet.maps) {
    return;
}

fixmystreet.roadworks.config = {
    tag_top: 'h3',
    colon: true,
    skip_delays: true,
    text_after: "<p>If you think this issue needs immediate attention you can continue your report below</p>"
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
