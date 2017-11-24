document.getElementById('pc').focus();

(function(){
    var around_forms = document.querySelectorAll('form[action*="around"]');
    for (var i=0; i<around_forms.length; i++) {
        var form = around_forms[i];
        var el = document.createElement('input');
        el.type = 'hidden';
        el.name = 'js';
        el.value = 1;
        form.insertBefore(el, form.firstChild);
    }
    var around_links = document.querySelectorAll('a[href*="around"]');
    for (i=0; i<around_links.length; i++) {
        var link = around_links[i];
        link.href = link.href + (link.href.indexOf('?') > -1 ? '&js=1' : '?js=1');
    }
})();
