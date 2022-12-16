fixmystreet.offlineReporting = (function() {
    $("form#offline_report").find("input, textarea").change(function() {
        fixmystreet.offlineReporting.saveDraft();
    });

    function updateDraftSavedTimestamp(ts) {
        $("#draft_save_message").removeClass("hidden").find("span").text(ts);
    }

    return {
         geolocate: function(pos) {
            $("input[name=latitude]").val(pos.coords.latitude.toFixed(6));
            $("input[name=longitude]").val(pos.coords.longitude.toFixed(6));
            $("#geolocate").hide();
            fixmystreet.offlineReporting.saveDraft();
         },

         saveDraft: function() {
            console.log("saveDraft");
            var ts = (new Date()).toISOString();
            idbKeyval.set('draftOfflineReports', [{
                latitude: $("input[name=latitude]").val(),
                longitude: $("input[name=longitude]").val(),
                title: $("input[name=title]").val(),
                detail: $("textarea[name=detail]").val(),
                saved: ts
            }]).then(function() {
                updateDraftSavedTimestamp(ts);
            });
         },

         restoreDraft: function() {
            idbKeyval.get('draftOfflineReports').then(function(drafts) {
                if (drafts && drafts.length) {
                    var d = drafts[0];
                    $("input[name=latitude]").val(d.latitude);
                    $("input[name=longitude]").val(d.longitude);
                    $("input[name=title]").val(d.title);
                    $("textarea[name=detail]").val(d.detail);
                    updateDraftSavedTimestamp(d.saved);
                }
            });
         },
    };
})();

(function(){

var link = document.getElementById('geolocate');
if (fixmystreet.geolocate && link) {
    fixmystreet.geolocate(link, fixmystreet.offlineReporting.geolocate);
}

fixmystreet.offlineReporting.restoreDraft();
})();