$(function(){

    var mm = $('#message_manager');

    $.getJSON('/cobrands/fixmybarangay/test-texts.json', function(data) {
        var items = [];
        $.each(data, function(k, v) {
            var item = $('<input type="radio"/>').attr({
                'id': 'mm_text_' + v.id,
                'name': 'mm_text',
                'value': v.text
            }).wrap('<p/>').parent().html();
            var label = $('<label/>', {
                'class': 'inline',
                'for': 'mm_text_' + v.id
            }).text(v.text).wrap('<p/>').parent().html();
            item = '<li><p>' + item + ' ' + label + '</p></li>';
            items.push(item);
        });
        mm.html(items.join(''));
        mm.find('input').click(function(){
            $('#form_detail').val( $('input[name=mm_text]:checked').val() );
        });
    });

});
