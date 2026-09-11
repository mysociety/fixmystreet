// jshint esversion: 6

// disable lead fields when "same as applicant" is checked
(function() {
    var checkbox = document.getElementById('lead_same_as_applicant-0');
    if (!checkbox) {
        return;
    }

    var leadFields = [
        'lead_organisation',
        'lead_contact_name',
        'lead_email',
        'lead_phone',
    ];

    function updateLeadFields() {
        var disabled = checkbox.checked;
        leadFields.forEach(function(fieldName) {
            var field = document.getElementById('form-' + fieldName + '-row');
            if (field) {
                field.classList.toggle('hidden-js', disabled);
            }
        });
    }

    checkbox.addEventListener('change', updateLeadFields);
    updateLeadFields();
})();

// Set up map layer...
$(function() {
    if (!fixmystreet.map) {
        return;
    }

    function toTitleCase(str) {
        return str.replace(/\w\S*/g, function(t) {
            return t.charAt(0).toUpperCase() + t.substring(1).toLowerCase();
        });
    }

    const BOROUGHS = [
        'City of London',
        'Westminster',
        'Camden',
        'Islington',
        'Hackney',
        'Tower Hamlets',
        'Greenwich',
        'Lewisham',
        'Southwark',
        'Lambeth',
        'Wandsworth',
        'Hammersmith & Fulham',
        'Kensington & Chelsea',
        'Waltham Forest',
        'Redbridge',
        'Havering',
        'Barking & Dagenham',
        'Newham',
        'Bexley',
        'Bromley',
        'Croydon',
        'Sutton',
        'Merton',
        'Kingston upon Thames',
        'Richmond upon Thames',
        'Hounslow',
        'Hillingdon',
        'Ealing',
        'Brent',
        'Harrow',
        'Barnet',
        'Haringey',
        'Enfield'
    ];

    function light_selected(e,f) {
        // Want LOCATION BOROUGH_NO ABBREVIATED_ID
        var feature = e.feature;
        $('#asset_location').val(toTitleCase(feature.attributes.LOCATION));
        $('#asset_borough').val(BOROUGHS[feature.attributes.BOROUGH_NO]);
        $('#asset_site_id').val(feature.attributes.ABBREVIATED_ID);
        $('#continue')[0].disabled = false;
    }

    function light_unselected() {
        $('#asset_location').val('');
        $('#asset_borough').val('');
        $('#asset_site_id').val('');
        $('#continue')[0].disabled = true;
    }

    var layer = fixmystreet.map.getLayersByName("TfL Traffic Lights")[0];
    layer.events.register('featureselected', layer, light_selected);
    layer.events.register('featureunselected', layer, light_unselected);
///    light_unselected();
    layer.setVisibility(true);
});
