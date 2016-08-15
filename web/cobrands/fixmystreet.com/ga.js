(function(i,s,o,g,r,a,m){i.GoogleAnalyticsObject=r;i[r]=i[r]||function(){
(i[r].q=i[r].q||[]).push(arguments);};i[r].l=1*new Date();a=s.createElement(o);
m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m);
})(window,document,'script','//www.google-analytics.com/analytics.js','ga');

ga('create', 'UA-660910-4', {'cookieDomain': '.fixmystreet.com'});
ga('set', 'anonymizeIp', true);

(function(w,d,s){

var created_report = document.getElementById('script_ga').getAttribute('data-created-report');
if (created_report) {
    ga('require', 'ecommerce');
    ga(function(tracker) {
        var page = tracker.get('location');
        var extra = '';
        if ( page.indexOf('?') != -1 ) {
            extra = '&created_report=1';
        } else {
            extra = '?created_report=1';
        }
        tracker.set('location', page + extra);
    });
    ga('ecommerce:addItem', {
        'id': 'report/' + created_report,
        'quantity': '1',
        'name': 'Report'
    });
    ga('ecommerce:send');
}

ga('send', 'pageview');

if (created_report) {
    var google_conversion_id = 1067468161;
    var google_conversion_language = "en";
    var google_conversion_format = "3";
    var google_conversion_color = "ffffff";
    var google_conversion_label = "1nWDCP3t6GQQgYuB_QM";
    var google_remarketing_only = false;
}

})(window,document);
