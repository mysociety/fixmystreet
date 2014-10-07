$(function() {

    $('#form_incident_date').datepicker({
        minDate: -((365 * 5)+1), // 5 years plus a fudge factor of 1 day for leap years
        maxDate: +0,
        defaultDate: +0,
        dateFormat: 'dd/mm/yy'
    });

    $('.describe-injury').hide();

    $('input[name="severity"]').on('change', function(){
        // Assumes the severity radio buttons have numeric values,
        // where a value over 0 implies injury.
        if( 0 + $('#mapForm')[0].severity.value > 10 ) {
            $('.describe-injury').slideDown();
        } else {
            $('.describe-injury').slideUp();
        }
    });

    $('#form_participants').on('change', function(){
        // In a stroke of genius, jQuery returns true for the :selected selector,
        // if *any* of the matched elements are :selected, rather than *all* of them.
        if( $('option[value="car"], option[value="motorcycle"], option[value="hgv"], option[value="other"]').is(':selected') ) {
            $('.vehicle-registration-number').slideDown();
        } else {
            $('.vehicle-registration-number').slideUp();
        }
    });

    var type = $('form.statistics-filter input[name=type]');
    type.on('change', function () {
        var val = $(this).val();
        if (val == 'all') {
            window.location = '/reports';
        }
        else if (val == 'london') {
            window.location = '/reports?type=LBO';
        }
        else if (val == 'city') {
            window.location = '/reports?type=UTA,MTD,COI';
        }
        else if (val == 'dc') {
            window.location = '/reports?type=CTY,DIS';
        }
    });

});
