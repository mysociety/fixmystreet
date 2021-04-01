// Disable roadworks for certain groups
fixmystreet.roadworks.filter = function(_feature) {
  var group = fixmystreet.reporting.selectedCategory().group;
  if (group === '') {
    return false;
  }
  var disabledGroups = [
      'Street Entertainment'
  ];
  return OpenLayers.Util.indexOf(disabledGroups, group) === -1;
};
