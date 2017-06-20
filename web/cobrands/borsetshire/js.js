(function(){
    $('#demo-user-list dt').click(function(){
        var form = document.forms.general_auth;
        form.email.value = $(this).text();
        form.password_sign_in.value = 'password';
        form.r.value = 'admin';
        form.submit();
    });
})();
