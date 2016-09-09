$.fn.link_track = function(eventCategory, eventAction, eventLabel) {
    this.on('click', function(e) {
        if (typeof ga === 'undefined') {
            return;
        }
        var url = $(this).attr('href'),
            name = $(this).attr('data-' + eventLabel),
            callback = function() {
                window.location.href = url;
            };
        if (e.metaKey || e.ctrlKey) {
            callback = function(){};
        } else {
            e.preventDefault();
        }
        if (typeof ga !== 'undefined') {
            ga('send', 'event', eventCategory, eventAction, name, {
                'hitCallback': callback
            });
            setTimeout(callback, 2000);
        } else {
            callback();
        }
    });
};

$(function() {
    $("[data-goodielink]").link_track('goodie', 'download', 'goodielink');
    $('.js-click-select').on('click', function() { this.select(); });
});
