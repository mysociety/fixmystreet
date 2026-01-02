$(function(){

    // hide/show categories with zero reports
    var $table_with_zeroes = $('table tr.is-zero').closest('table');

    if ($table_with_zeroes.length == 1) {
        var $toggle_zeroes_btn = $("<input type='submit' class='btn' value='Show categories with zero reports' id='toggle-zeroes-btn' style='margin:1em 0;'/>");
        $table_with_zeroes.before($toggle_zeroes_btn);
        $toggle_zeroes_btn.on('click', function(e){
            e.preventDefault();
            var $cols = $table_with_zeroes.find('tr.is-zero');
            if ($cols.first().is(':visible')) {
                $cols.hide();
                $(this).prop("value", 'Show categories with zero reports');
            } else {
                $cols.show();
                $(this).prop("value", 'Hide categories with zero reports');
            }

            toggleGroupHeadings();
        });
    }

    // hide/show deleted contact categories
    var $table_with_deleted_contacts = $('table tr.is-deleted').closest('table');

    if ($table_with_deleted_contacts.length == 1) {
        var $toggle_deleted_btn = $("<input type='submit' class='btn' value='Show deleted categories' id='toggle-deleted-contacts-btn' style='margin:1em 0;'/>");
        $table_with_deleted_contacts.before($toggle_deleted_btn);
        $toggle_deleted_btn.on('click', function(e){
            e.preventDefault();
            var $cols = $table_with_deleted_contacts.find('tr.is-deleted');
            if ($cols.first().is(':visible')) {
                $cols.hide();
                $(this).prop("value", 'Show deleted categories');
            } else {
                $cols.show();
                $(this).prop("value", 'Hide deleted categories');
            }

            toggleGroupHeadings();
        });
    }

    function toggleGroupHeadings() {
        var $rows = $('table#overview tr');
        var $current_group_heading;
        var $visible_count = 0;

        $rows.each( function( idx, elem ) {
            if ( $(this).hasClass('group-heading') ) {
                // Hide previous group heading if no visible categories
                if ($current_group_heading) {
                    if ( $visible_count == 0 ) {
                        $current_group_heading.hide();
                    } else {
                        $current_group_heading.show();
                    }
                }

                // Then set next group heading
                $current_group_heading = $(this);
                $visible_count = 0;

            } else {
                if ( $(this).is(':visible') ) {
                    $visible_count++;
                }
            }
        });
    }

    toggleGroupHeadings();

});
