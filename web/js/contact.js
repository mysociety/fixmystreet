$('[name=dest]').change(function() {
    var err = $('.form-error--' + this.value),
        inputs = $(this).closest('form').find('input[type=text], input[type=submit]');
    $('.form-error__box').addClass('hidden');
    if (err.length) {
        $('#dest-error').removeClass('hidden');
        $('#dest-error .form-error').show(); // might have been hidden by normal validate
        inputs.prop('disabled', true);
        $('.form-error--' + this.value).removeClass('hidden');
    } else {
        $('#dest-error').addClass('hidden');
        inputs.prop('disabled', false);
    }
});
