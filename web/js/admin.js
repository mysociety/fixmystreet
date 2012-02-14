$(function() {
    $('#add_allowed_row').click(function() {
        var add = $(this);
        var row = add.prev().attr('id');
        row = row.replace('cobrand_host_', '');
        row++;
        var p = add.parent();

        p.after('<p class="cobrand-entry"><input id="cobrand_name_' + row + '" name="cobrand_name_' + row + '" />  : <input id="cobrand_host_' + row + '" name="cobrand_host_' + row + '" /> </p>' );
        add.detach();
        add.appendTo( p.next() );
    });
});
