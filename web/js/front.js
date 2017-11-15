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
})();
