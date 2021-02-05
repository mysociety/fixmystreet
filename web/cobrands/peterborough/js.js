fixmystreet.roadworks.filter = function(feature) {
  var category = fixmystreet.reporting.selectedCategory().category,
      categories = [
        'Blocked drainage gully', 'Bollard', 'Bollard - lit', 'Column/lantern damaged/leaning',
        'Damaged or missing cover', 'Damaged or missing utility cover', 'Damaged structure',
        'Damaged Telecomms cabinet', 'Flooded road', 'Flooded underpass', 'Highways - Emergency',
        'Light blocked', 'Light on during day', 'Lighting enquiry', 'Multiple lights out/flickering',
        'Other emergency', 'Other public drainage issue', 'Other public road issue', 'Pavement cleaning',
        'Pedestrian railing', 'Permanent', 'Pothole', 'Problem with a light not shown on map',
        'Public footpath or cyclepath', 'Public right of way - problem with access or damage',
        'Road Traffic Accident', 'Road works', 'Safety fence or barrier', 'Seats and benches',
        'Single light out/flickering', 'Street nameplate', 'Street sweeping', 'Temporary',
        'Traffic sign', 'Traffic sign - lit', 'Wires exposed/Door off'
      ];
    return OpenLayers.Util.indexOf(categories, category) != -1;
};

