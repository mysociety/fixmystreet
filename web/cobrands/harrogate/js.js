// we link to the informational articles rather than the forms, because in some
// cases the former have more information or links to track progress of faults
// etc..

(function() {

var links = {
    'Bus stops': 'http://www.northyorks.gov.uk/article/25853/Bus-stops-and-shelters',
    // Pavements/footpaths (multiple options)
    'Potholes': 'http://www.northyorks.gov.uk/article/25215/Roads---potholes',
    // Roads/highways (multiple options)
    'Road traffic signs': 'http://www.northyorks.gov.uk/article/25667/Road-signs-and-bollards',
    // Street lighting (not considered, as also a Harrogate category)
    'Traffic lights': 'http://www.northyorks.gov.uk/article/25626/Traffic-lights',
    'default': 'http://www.northyorks.gov.uk/article/28237/Report-it-online'
};

$(function () {
    var notice = $('.nycc-notice');
    $("#problem_form").on("change.category", "select#form_category", function(){
        var cat = $(this).val();
        if (cat.search(/NYCC/) > 0) {
            cat = cat.replace(' (NYCC)', '');
            var link = links[cat] || links ['default'];
            notice.find('a').attr({ href: link });
            notice.show();
        }
        else {
            notice.hide();
        }
    });
});

})();
