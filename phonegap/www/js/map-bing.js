$(function(){
    var centre = new Microsoft.Maps.Location( fixmystreet.latitude, fixmystreet.longitude );
    var map = new Microsoft.Maps.Map(document.getElementById("map"), {
        credentials: fixmystreet.key,
        mapTypeId: Microsoft.Maps.MapTypeId.ordnanceSurvey,
        center: centre,
        zoom: 15,
        enableClickableLogo: false,
        enableSearchLogo: false,
        showCopyright: false,
        showDashboard: true,
        showLogo: false,
        showScalebar: false
    });
        //minZoomLevel: 14,
        //numZoomLevels: 4

    Microsoft.Maps.Events.addHandler(map, "viewchangestart", function(e) {
        /* Doesn't work */
        if (map.getTargetZoom() < 12) { return false; }
    });
});
