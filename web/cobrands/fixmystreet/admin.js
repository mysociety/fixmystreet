$(function(){
    // available for admin pages

    // hide the open311_only section and reveal it only when send_method is relevant
    function hide_or_show_open311(e, hide_fast) {
        var $form = $(this).closest("form");
        var $open311_only = $form.find('.admin-open311-only');

        var send_method = $(this).val();
        var show_open311 = false;
        if ($form.find('[name=endpoint]').val()) {
            show_open311 = true; // always show the form if there is an endpoint value
        } else if (send_method && !send_method.match(/email|^noop$|^refused$/i)) {
            show_open311 = true;
        }
        if (show_open311) {
            $open311_only.slideDown();
        } else {
            if (hide_fast) {
                $open311_only.hide();
            } else {
                $open311_only.slideUp();
            }
        }
    }

    if ($('.admin-open311-only').length) {
        // Add handler to send_method dropdowns and set initial visibility
        $('[name=send_method]').on('change', hide_or_show_open311).each(function() {
            hide_or_show_open311.call(this, null, true);
        });
    }

    // Some lists of checkboxes have 'select all/none' links at the top
    $("a[data-select-none], a[data-select-all]").click(function(e) {
        e.preventDefault();
        var checked = $(this).filter('[data-select-all]').length > 0;
        $(this).closest("ul").find('input[type=checkbox]').prop('checked', checked);
    });


    // admin hints: maybe better implemented as tooltips?
    $(".admin").on('click', ".admin-hint", function(){
        if ($(this).hasClass('admin-hint-show')) {
            $(this).removeClass('admin-hint-show');
        } else {
            $(this).addClass('admin-hint-show');
        }
    });

    // on a body's page, hide/show deleted contact categories
    var $table_with_deleted_contacts = $('table tr.is-deleted td.contact-category').closest('table');
    if ($table_with_deleted_contacts.length == 1) {
        var $toggle_deleted_btn = $("<input type='submit' class='btn' value='Show deleted contacts' id='toggle-deleted-contacts-btn' style='margin:1em 0;'/>");
        $table_with_deleted_contacts.before($toggle_deleted_btn);
        $toggle_deleted_btn.on('click', function(e){
            e.preventDefault();
            var $cols = $table_with_deleted_contacts.find('tr.is-deleted');
            if ($cols.first().is(':visible')) {
                $cols.hide();
                $(this).prop("value", 'Show deleted contacts');
            } else {
                $cols.show();
                $(this).prop("value", 'Hide deleted contacts');
            }
        });
    }

    $("#start_date").change(function(){
        $('#end_date').attr('min', $(this).val());
    });
    $("#end_date").change(function(){
        $('#start_date').attr('max', $(this).val());
    });

    // On user edit page, hide the area/categories fields if body changes
    $("form#user_edit select#body").change(function() {
        var show_area = $(this).val() == $(this).find("[data-originally-selected]").val();
        $("form#user_edit select#area_ids").closest("li").toggle(show_area);
        $("form#user_edit .js-user-categories").toggle(show_area);
    });

    $('form#user_edit select#roles').change(function() {
        var $perms = $('.permissions-checkboxes');
        if ($(this).val()) {
            var selected_perms = {};
            $(this).find(':selected').each(function() {
                $.each($(this).data('permissions'), function(i, p) {
                    selected_perms['permissions[' + p + ']'] = 1;
                });
            });
            $perms.css('color', '#666');
            $perms.find('a').css('color', '#666');
            $perms.find('input').each(function() {
                this.checked = selected_perms[this.name] || false;
            });
            $perms.find('input').prop('disabled', true);
        } else {
            $perms.css('color', '');
            $perms.find('a').css('color', '');
            $perms.find('input').each(function() {
                this.checked = this.hasAttribute('checked');
            });
            $perms.find('input').prop('disabled', false);
        }
    }).change();

    // Bits for the report extra fields form builder:

    // Reveal the UI when 'show' link is clicked
    $(".js-show-extra-fields").click(function(e) {
        e.preventDefault();
        $(this).hide();
        $(".js-extra-fields-ui").removeClass("hidden-js");
    });

    // For "parent categories"
    $(".js-group-item-add").on("click", function(e) {
        e.preventDefault();
        var $template_item = $(".js-group-item-template");
        var $new_item = $template_item.clone();
        $new_item.removeClass("hidden-js js-group-item-template");
        $new_item.insertBefore($template_item);
        $new_item.focus();
        return true;
    });

    $('.js-metadata-item-add').on('click', function(){
        var $container = $(this).prevAll('.js-metadata-items');
        var i = $container.children().length + 1;
        var html = $('#js-template-extra-metadata-item').html().replace(/9999/g, i);
        $container.append(html);
        fixmystreet.set_up.toggle_visibility();
        reloadSortableMetadataItems();
    });

    $('.js-metadata-items').on('click', '.js-metadata-item-remove', function(){
        $(this).parents('.js-metadata-item').remove();
    }).on('change', '.js-metadata-item', updateMetadataItemTitle);

    var items = sortable('.js-metadata-items', {
        forcePlaceholderSize: true,
        handle: '.js-metadata-item-header-grab',
        placeholder: '<div class="extra-metadata-item-placeholder"></div>'
    });
    if (items.length) {
        items[0].addEventListener('sortupdate', function(e) {
            $(e.detail.destination.items).each(function(i){
                $(this).find('.js-sort-order input').val(i);
            });
        });
    }
    $('.js-sort-order').addClass('hidden-js');

    function reloadSortableMetadataItems(){
        sortable('.js-metadata-items', 'reload');
        $('.js-sort-order').addClass('hidden-js');
    }

    $('.js-metadata-item').each(updateMetadataItemTitle);

    function updateMetadataItemTitle(){
        var $title = $(this).find('.js-metadata-item-header-title');
        var defaultTitle = $title.attr('data-default');
        var html = '<strong>' + defaultTitle + '</strong>';
        var code = $(this).find('input[name$=".code"]').val();
        if ( code ) {
            html = '<strong>' + code + '</strong>';
            var behaviour = $(this).find('input[name$=".behaviour"]:checked');
            if ( behaviour.length ) {
                html += ' / ' + behaviour.val();
            }
            var description = $(this).find('textarea[name$=".description"]').val();
            if ( description && (behaviour.val() == 'question' || behaviour.val() == 'notice') ) {
                html += ' / ' + description.substring(0, 50);
            }
        }
        $title.html(html);
    }

    $('.js-metadata-items').on('click', '.js-metadata-option-add', function(){
        var $container = $(this).prevAll('.js-metadata-options');
        var i = $(this).parents('.js-metadata-item').attr('data-i');
        var j = $container.children().length + 1;
        var html = $('#js-template-extra-metadata-option').html().replace(/9999/g, i).replace(/8888/g, j);
        $container.append(html);
        fixmystreet.set_up.toggle_visibility();
    });

    $('.js-metadata-items').on('click', '.js-metadata-option-remove', function(){
        $(this).parents('.js-metadata-option').remove();
    });

    // On the manifest theme editing page we have tickboxes for deleting individual
    // icons - ticking one of these should grey out that row to indicate it will be
    // deleted upon form submission.
    $("input[name=delete_icon]").change(function() {
        $(this).closest("tr").toggleClass("is-deleted", this.checked);
    });
});

