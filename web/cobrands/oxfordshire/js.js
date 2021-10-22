///*
(function(){
    $(document).on('change', '#defect_item_category', function(){
        var item = document.getElementById('defect_item_category');
        var type = document.getElementById('defect_item_type');
        var detail = document.getElementById('defect_item_detail');
        var opt = item.options[item.selectedIndex].value;
        // reset all if '-- Pick' option chosen
        if (item.selectedIndex === 0){
            type.selectedIndex = 0;
            detail.selectedIndex = 0;
            return;
        }
        var event = document.createEvent("Event");
        event.initEvent("change", true, false);
        type.dispatchEvent(event);
        var optgroups = type.children;
        // don't get stuck on stale options
        // start at 1 to miss out '-- Pick a type --'
        for (var i=1; i<optgroups.length; i++) {
            var group = optgroups[i];
            var regex = new RegExp(opt);
            if (regex.test(group.label)) {
                // select first option of correct type
                group.querySelector('option:first-child').selected = true;
                break;
            }
        }
        // now process detail dropdown to match type
        show_relevant_details();
    });

    $(document).on('change', '#defect_item_type', function(){
        show_relevant_details();
    });

    function show_relevant_details() {
        var type = document.getElementById('defect_item_type');
        var selected = type.selectedOptions;
        var detail = document.getElementById('defect_item_detail');
        // find text value & optgroup label of selected defect type
        var type_text = selected[0].innerText;
        var type_label = selected[0].parentElement.label;
        // hide all detail options, then show options of correct type
        var optgroups = detail.children;
        // handle type being manually set to -- Pick a type --
        if (/--/.test(type_text)) {
            // set to -- Pick a detail --
            detail.selectedIndex = 0;
            // show all groups
            for (var i=1; i<optgroups.length; i++) {
                optgroups[i].style.display = '';
            }
        } else {
            var type_source;
            if (type_label === 'Kerbing' || type_label === 'Drainage') {
                type_source = type_label;
            } else {
                type_source = type_text;
            }
            // start at 1 to always show -- Pick a detail --
            for (var j=1; j<optgroups.length; j++) {
                var group = optgroups[j];
                var detail_text = group.label;
                // hide any groups that don't match the defect type
                if (detail_text === type_source) {
                    // show this group
                    group.style.display = '';
                    // select first detail option of correct type
                    group.querySelector('option:first-child').selected = true;
                } else {
                    group.style.display = 'none';
                }
            }
        }
    }
})();
//*/
