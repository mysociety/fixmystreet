$(function(){
    var centre = new google.maps.LatLng( fixmystreet.latitude, fixmystreet.longitude );
    var map = new google.maps.Map(document.getElementById("map"), {
        mapTypeId: google.maps.MapTypeId.ROADMAP,
        center: centre,
        zoom: 16,
        disableDefaultUI: true,
        navigationControl: true,
        navigationControlOptions: {
            style: google.maps.NavigationControlStyle.SMALL
        },
        mapTypeControl: true,
        mapTypeControlOptions: {
            style: google.maps.MapTypeControlStyle.DROPDOWN_MENU
        }
    });

    google.maps.event.addListener(map, "zoom_changed", function() {
        if (map.getZoom() < 13) { map.setZoom(13); }
        if (map.getZoom() > 17) { map.setZoom(17); }
    });
});
