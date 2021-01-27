fixmystreet.roadworks.config = {
    tag_top: 'h3',
    colon: true,
    text_after: "<p>If you think this issue needs immediate attention you can continue your report below</p>"
};

fixmystreet.roadworks.filter = function(feature) {
  var category = fixmystreet.reporting.selectedCategory().category,
      categories = ['Damage to pavement', 'Damage to road', 'Faded road markings', 'Damaged Railing, manhole, or drain cover'];
    return OpenLayers.Util.indexOf(categories, category) != -1;
};
