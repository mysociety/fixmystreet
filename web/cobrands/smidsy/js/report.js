$(function() {

    $('#form_incident_date').datepicker({
        minDate: -7,
        maxDate: +0,
        defaultDate: +0,
        dateFormat: 'dd/mm/yy'
    });

    $('.describe-injury').hide();

    $('input[name="severity"]').on('change', function(){
        // Assumes the severity radio buttons have numeric values,
        // where a value over 0 implies injury.
        if( 0 + $('#mapForm')[0].severity.value > 0 ) {
            $('.describe-injury').slideDown();
        } else {
            $('.describe-injury').slideUp();
        }
    });

    $('#form_participants').on('change', function(){
        // In a stroke of genius, jQuery returns true for the :selected selector,
        // if *any* of the matched elements are :selected, rather than *all* of them.
        if( $('option[value="bike-car"], option[value="bike-motorcycle"], option[value="bike-hgv"], option[value="bike-other"]').is(':selected') ) {
            $('.vehicle-registration-number').slideDown();
        } else {
            $('.vehicle-registration-number').slideUp();
        }
    });

});
