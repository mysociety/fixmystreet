if (!$('#offline_list').length) {
    if (window.applicationCache && window.localStorage) {
        $(document.body).prepend('<iframe src="/offline/appcache" style="position:absolute;top:-999em;visibility:hidden"></iframe>');
    }
}
