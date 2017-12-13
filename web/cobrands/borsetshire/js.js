(function(){

    if (typeof jQuery === 'undefined') {
        return;
    }

    function set_redirect(form) {
        var e = form.username.value;
        if (e == 'inspector@example.org') {
            form.r.value = 'my/planned';
        } else if (e == 'cs@example.org') {
            form.r.value = 'reports';
        } else if (e == 'super@example.org') {
            form.r.value = 'admin';
        }
    }

    $('#demo-user-list button').click(function(){
        var form = document.forms.general_auth;
        form.username.value = $(this).data('email');
        form.password_sign_in.value = 'password';
        set_redirect(form);
        form.submit();
    });

    $('form[name=general_auth]').on('submit', function() {
        set_redirect(this);
    });

})();
