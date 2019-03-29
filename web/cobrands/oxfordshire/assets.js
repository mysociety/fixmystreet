(function(){

function check_rights_of_way() {
    var relevant_body = OpenLayers.Util.indexOf(fixmystreet.bodies, 'Oxfordshire County Council') > -1;
    var relevant_cat = $('#form_category').val() == 'Countryside Paths / Public Rights of Way (usually not tarmac)';
    var relevant = relevant_body && relevant_cat;
    var currently_shown = !!$('#occ_prow').length;

    if (relevant === currently_shown) {
        // Either should be shown and already is, or shouldn't be shown and isn't
        return;
    }

    if (!relevant) {
        $('#occ_prow').remove();
        $('.js-hide-if-invalid-category').show();
        return;
    }

    var $msg = $('<p id="occ_prow" class="box-warning">Please report problems with rights of way using <a href="https://publicrightsofway.oxfordshire.gov.uk/web/standardmap.aspx">this page</a>.</p>');
    $msg.insertBefore('#js-post-category-messages');
    $('.js-hide-if-invalid-category').hide();
}
$(fixmystreet).on('report_new:category_change', check_rights_of_way);

})();
