(function(){
    function showContinueDraftUI(drafts) {
        // Don't show on continuing draft or offline pages
        if (location.search.indexOf("restoreDraft=") > 0 || document.getElementById('offline_report')) {
            return;
        }

        var urlParams = new URLSearchParams(location.search);
        if (urlParams.has('setDraftLocation')) {

            var draftId =  urlParams.get('setDraftLocation');
            if (!drafts.hasOwnProperty(draftId)) {
                return;
            }
            var draft = drafts[draftId];

            var postcodeForm = document.getElementById('postcodeForm');
            if (postcodeForm) {
                var setDraftLocation = document.createElement("input");
                setDraftLocation.name = "setDraftLocation";
                setDraftLocation.value = urlParams.get('setDraftLocation');
                setDraftLocation.type = "hidden";
                postcodeForm.appendChild(setDraftLocation);
            }

            var draftName = draft.title;
            if (draftName) {
                document.querySelectorAll(".js-draft-name").forEach(function(e) {
                    e.textContent = ' "' + draftName + '"';
                });
            }

            document.querySelectorAll(".js-setting-location-for-draft").forEach(function(e) {
                e.classList.remove('hidden');
            });

            return;
        }

        document.querySelectorAll(".js-continue-draft").forEach(function(p) {
            p.classList.remove("hidden");
            p.querySelectorAll("a").forEach(function(a) {
                a.href = "/offline/drafts";
            });
        });

        document.querySelector("#nav-link").classList.add("indicator");
    }

    if (window.idbKeyval) {
        idbKeyval.get('draftOfflineReports').then(function(drafts) {
            if (drafts && drafts.length) {
                showContinueDraftUI(drafts);
            }
        });
    }

})();
