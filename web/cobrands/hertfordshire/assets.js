// jshint esversion: 6

$(fixmystreet).on('report_new:category_change', function() {
    // Show/hide a field as required
    function update_field(s, show, required_field) {
        $(`#form_${s}, #form_${s}-error, label[for=form_${s}]`).toggle(show);
        if (required_field) {
            $(`input#form_${s}, select#form_${s}, fieldset#form_${s} input`).toggleClass('required', show);
        }
    }

    // Remove the non-JS text that won't be needed
    $('label[for=form_Depth1], label[for=form_Depth2]').each(function(i,label) {
        label.innerText = label.innerText.replace(/^\[.*?\] /, '');
    });

    // Set up extra data field show/hides depending on what category has been picked
    const selected = fixmystreet.reporting.selectedCategory();
    if (selected.category === 'Manhole or drain cover missing, damaged or loose') {
        $('#form_Noise_Yes').on('change', i => {
            update_field('Problem', false, true);
            update_field('Where', false, true);
            update_field('Which', false);
            update_field('Barriers', false, true);
        });
        $('#form_Noise_No').on('change', i => {
            update_field('Problem', true, true);
            update_field('Where', true, true);
            update_field('Which', true);
            $('#form_Problem').change();
        });
        $('#form_Problem').on('change', i => {
            update_field('Barriers', i.target.value == 'Collapsed', true);
        });
        const checked = $('#form_Noise input:checked');
        if (checked.length) {
            checked.change();
        } else {
            $('#form_Noise_Yes').change();
        }
    } else if (selected.category === 'Manhole or drain cover sunken') {
        $('#form_Noise_Yes').on('change', i => {
            update_field('Where', false, true);
            update_field('Depth1', false, true);
            update_field('Depth2', false, true);
            update_field('Which', false);
        });
        $('#form_Noise_No').on('change', i => {
            update_field('Where', true, true);
        });
        $('#form_Where').on('change', i => {
            update_field('Depth1', !!i.target.value && i.target.value !== 'Cycle', true);
            update_field('Depth2', i.target.value === 'Cycle', true);
            update_field('Which', !!i.target.value);
        });
        const checked = $('#form_Noise input:checked');
        if (checked.length) {
            checked.change();
        } else {
            $('#form_Noise_Yes').change();
        }
        $('#form_Where').change();
    } else if (selected.category === 'Sudden change in surface level') {
        $('#form_Where').on('change', i => {
            update_field('Depth1', !!i.target.value && i.target.value !== 'Cycle', true);
            update_field('Depth2', i.target.value === 'Cycle', true);
            update_field('Description', !!i.target.value);
        }).change();
    } else if (selected.category === 'Pothole') {
        $('#form_Type, #form_Depth1, #form_Depth2').on('change', i => {
            // The Chunks question is asked for all but first depth, for not-unclassified roads
            const road_type = $('#form_Type').val();
            const depth = $('#form_Depth1, #form_Depth2').filter(':visible').val();
            if (!depth || depth === '0' || !road_type || road_type === 'U') {
                update_field('Chunks', false, true);
            } else {
                update_field('Chunks', true, true);
            }
        });
        $('#form_Where').on('change', i => {
            update_field('Depth1', !!i.target.value && i.target.value !== 'Cycle', true);
            update_field('Depth2', i.target.value === 'Cycle', true);
            update_field('Width', !!i.target.value);
            if (i.target.value === 'Cycle') {
                $('#form_Depth2').change();
            } else if (i.target.value) {
                $('#form_Depth1').change();
            } else {
                update_field('Chunks', false, true);
            }
        }).change();
    } else if (selected.category === 'Roadwork, signs and barriers') {
        $('#form_Obstruction').on('change', i => {
            update_field('Complete', i.target.value === 'No', true);
        }).change();
    }
});
