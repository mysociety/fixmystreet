(function(){
    var each = function(selector, callback) {
        var elements = document.querySelectorAll(selector);
        for (var i=0; i<elements.length; i++) {
            callback(elements[i]);
        }
    };

    var goToSearch = function(e){
        if (e) { e.preventDefault(); }
        var form = document.querySelectorAll('#postcodeForm')[0];
        if (form) {
            window.scroll(0, form.getBoundingClientRect().top + window.scrollY);
            document.querySelectorAll('#pc')[0].focus();
        }
    };

    document.querySelectorAll('#pc')[0].focus();

    each('form[action*="around"]', function(form){
        var el = document.createElement('input');
        el.type = 'hidden';
        el.name = 'js';
        el.value = 1;
        form.insertBefore(el, form.firstChild);
    });

    each('a[href*="around"]', function(link){
        link.href = link.href + (link.href.indexOf('?') > -1 ? '&js=1' : '?js=1');
    });

    each('span.report-a-problem-btn', function(el){
        el.addEventListener('click', goToSearch);
    });

    each('#report-cta', function(el){
        el.addEventListener('click', goToSearch);
    });
})();
