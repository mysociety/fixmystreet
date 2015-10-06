function setup_moderation (elem, word) {

    elem.each( function () {
        var $elem = $(this);
        $elem.find('.moderate').click( function () {
            $elem.find('.moderate-display').hide();
            $elem.find('.moderate-edit').show();
        });

        $elem.find('.revert-title').change( function () {
            $elem.find('input[name=problem_title]').prop('disabled', $(this).prop('checked'));
        });
        $elem.find('.revert-textarea').change( function () {
            $elem.find('textarea').prop('disabled', $(this).prop('checked'));
        });

        var hide_document = $elem.find('.hide-document');
        hide_document.change( function () {
            $elem.find('input[name=problem_title]').prop('disabled', $(this).prop('checked'));
            $elem.find('textarea').prop('disabled', $(this).prop('checked'));
            $elem.find('input[type=checkbox]').prop('disabled', $(this).prop('checked'));
            $(this).prop('disabled', false); // in case disabled above
        });

        $elem.find('.cancel').click( function () {
            $elem.find('.moderate-display').show();
            $elem.find('.moderate-edit').hide();
        });

        $elem.find('form').submit( function () {
            if (hide_document.prop('checked')) {
                return confirm('This will hide the ' + word + ' completely!  (You will not be able to undo this without contacting support.)');
            }
            return true;
        });
    });
}

$(function () {
    setup_moderation( $('.problem-header'), 'problem' );
    setup_moderation( $('.item-list__item--updates'), 'update' );
});
