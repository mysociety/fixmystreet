(function(){

    if (typeof jQuery === 'undefined') {
        return;
    }

    $('form[name=general_auth]').on('submit', function() {
        fixmystreet.borsetshire.set_redirect(this);
    });

})();
