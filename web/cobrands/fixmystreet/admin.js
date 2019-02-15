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

    // On category edit page, hide the reputation input if inspection isn't required
    $("form#category_edit #inspection_required").change(function() {
        var $p = $("form#category_edit #reputation_threshold").closest("p");
        var $hint = $p.prevUntil().first();
        if (this.checked) {
            $p.removeClass("hidden");
            if ($hint.length) {
                $hint.removeClass("hidden");
            }
        } else {
            $p.addClass("hidden");
            if ($hint.length) {
                $hint.addClass("hidden");
            }
        }
    });

    // Bits for the report extra fields form builder:

    // Reveal the UI when 'show' link is clicked
    $(".js-show-extra-fields").click(function(e) {
        e.preventDefault();
        $(this).hide();
        $(".js-extra-fields-ui").removeClass("hidden-js");
    });

    // If type is changed to 'singlevaluelist' show the options list
    $(".js-metadata-items").on("change", ".js-metadata-item-type", function() {
        var $this = $(this);
        var shown = $this.val() === 'singlevaluelist';
        var $list = $this.closest(".js-metadata-item").find('.js-metadata-options');
        $list.toggle(shown);
    });
    // call immediately to perform page setup
    $(".js-metadata-item-type").change();

    // Options can be removed by clicking the 'remove' button
    $(".js-metadata-items").on("click", ".js-metadata-option-remove", function(e) {
        e.preventDefault();
        var $this = $(this);
        var $item = $this.closest(".js-metadata-item");
        $this.closest('li').remove();
        return true;
    });

    // New options can be added by clicking the appropriate button
    $(".js-metadata-items").on("click", ".js-metadata-option-add", function(e) {
        e.preventDefault();
        var $ul = $(this).closest("ul");
        var $template_option = $ul.find(".js-metadata-option-template");
        var $new_option = $template_option.clone();
        $new_option.removeClass("hidden-js js-metadata-option-template");
        $new_option.show();
        $new_option.insertBefore($template_option);
        $new_option.find("input").first().focus();
        renumber_metadata_options($(this).closest(".js-metadata-item"));
        return true;
    });

    // Fields can be added/removed
    $(".js-metadata-item-add").on("click", function(e) {
        e.preventDefault();
        var $template_item = $(".js-metadata-items .js-metadata-item-template");
        var $new_item = $template_item.clone();
        $new_item.data('index', Math.max.apply(
            null,
            $(".js-metadata-item").map(function() {
                return $(this).data('index');
            }).get()
        ) + 1);
        renumber_metadata_fields($new_item);
        $new_item.removeClass("hidden-js js-metadata-item-template");
        $new_item.show();
        $new_item.insertBefore($template_item);
        $new_item.find("input").first().focus();
        return true;
    });
    $(".js-metadata-items").on("click", ".js-metadata-item-remove", function(e) {
        e.preventDefault();
        $(this).closest(".js-metadata-item").remove();
        return true;
    });

    function renumber_metadata_fields($item) {
        var item_index = $item.data("index");
        $item.find("[data-field-name]").each(function(i) {
            var $input = $(this);
            var prefix = "metadata["+item_index+"].";
            var name = prefix + $input.data("fieldName");
            $input.attr("name", name);
        });
    }

    function renumber_metadata_options($item) {
        var item_index = $item.data("index");
        $item.find(".js-metadata-option").each(function(i) {
            var $li = $(this);
            var prefix = "metadata["+item_index+"].values["+i+"]";
            $li.find(".js-metadata-option-key").attr("name", prefix+".key");
            $li.find(".js-metadata-option-name").attr("name", prefix+".name");
        });
    }
});

