fixmystreet.offlineReporting = (function() {
    function updateDraftSavedTimestamp(ts) {
        $("#draft_save_message").removeClass("hidden").find("span").text(ts);
    }

    return {
        offlineFormSetup: function() {
            $("form#offline_report").find("input, textarea").on("input", function() {
                fixmystreet.offlineReporting.saveDraft();
            });
            fixmystreet.offlineReporting.restoreDraft();
        },
         geolocate: function(pos) {
            $("input[name=latitude]").val(pos.coords.latitude.toFixed(6));
            $("input[name=longitude]").val(pos.coords.longitude.toFixed(6));
            $("#geolocate").hide();
            fixmystreet.offlineReporting.saveDraft();
         },

         saveDraft: function() {
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

         reportNewSetup: function() {
            if (location.search.indexOf("restoreDraft=1") > 0) {
                idbKeyval.get('draftOfflineReports').then(function(drafts) {
                    if (drafts && drafts.length) {
                        var d = drafts[0];
                        $("input[name=title]").val(d.title);
                        $("textarea[name=detail]").val(d.detail);

                        $("input[name=title], textarea[name=detail]").on("input", function() {
                            fixmystreet.offlineReporting.saveDraft();
                        });
                    }
                });
            }
         },

         frontPageSetup: function() {
            if (!window.idbKeyval) {
                return;
            }
            idbKeyval.get('draftOfflineReports').then(function(drafts) {
                if (drafts && drafts.length) {
                    var d = drafts[0];
                    document.querySelector(".js-continue-draft").className = "";
                    var lk = document.querySelector('a.continue-draft-btn');
                    lk.href = "/report/new?restoreDraft=1&latitude=" + d.latitude + "&longitude=" + d.longitude;
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

if (document.getElementById('offline_report')) {
    fixmystreet.offlineReporting.offlineFormSetup();
}
})();