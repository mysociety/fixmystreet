$(function () {
    setup_moderation( $('.problem-header') );
    setup_moderation( $('.issue-list .issue') );
});

function setup_moderation (elem) {

    elem.each( function () {
        var $elem = $(this)
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

        $elem.find('.cancel').click( function () {
            $elem.find('.moderate-display').show();
            $elem.find('.moderate-edit').hide();
        });
    });
}
