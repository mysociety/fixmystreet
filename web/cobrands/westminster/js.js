// Disable roadworks for certain groups
fixmystreet.roadworks.filter = function(_feature) {
  var group = fixmystreet.reporting.selectedCategory().group;
  if (group === '') {
    return false;
  }
  var disabledGroups = [
      'Busking and Street performance'
  ];
  return OpenLayers.Util.indexOf(disabledGroups, group) === -1;
};
