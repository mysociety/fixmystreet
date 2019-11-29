fixmystreet.inspect_form_no_scroll_on_load = 1;

// Chrome ignores autocomplete="off" on the title input,
// and incorrectly autocompletes it with the user's email address.
// For now we'll reset the title to empty if it contains
// an email address when the user has selected a category.
// Hopefully we can get rid of this eventually if Chrome changes
// its behaviour.
fixmystreet.fixChromeAutocomplete = function() {
    var title = document.getElementById("form_title");

    if (title) {
	if (title.value == "" ||
	    /^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@(?:\S{1,63})$/.test(title.value)) {
            title.value = "";
        }
    }
};

$(fixmystreet).on('report_new:category_change', fixmystreet.fixChromeAutocomplete);
