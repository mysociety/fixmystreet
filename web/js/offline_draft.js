(function(){
    function showContinueDraftUI(d) {
        // Don't show on continuing draft or offline pages
        if (location.search.indexOf("restoreDraft=") > 0 || document.getElementById('offline_report')) {
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
                var d = drafts[0];
                showContinueDraftUI(d);
            }
        });
    }

})();
