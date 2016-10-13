$(function() {

    $('#form_incident_date').datepicker({
        minDate: -((365 * 5)+1), // 5 years plus a fudge factor of 1 day for leap years
        maxDate: +0,
        defaultDate: +0,
        dateFormat: 'dd/mm/yy'
    });

    $('input[name="severity"]').on('change', function(){
        // Assumes the severity radio buttons have numeric values,
        // where a value over 0 implies injury.
        if( ($('#mapForm input[name="severity"]:checked').val() -0) > 10) {
            $('.describe-injury').slideDown();
        } else {
            $('.describe-injury').slideUp(
                // slideUp doesn't happen if element already hidden.
                // But it does call callback so hide when complete.
                // (We hide on callback, to avoid the hide killing the slide
                // animation entirely.)
                function () { $(this).hide(); }
            );
        }
    }).change(); // and call on page load

    $('#form_participants').on('change', function(){
        // In a stroke of genius, jQuery returns true for the :selected selector,
        // if *any* of the matched elements are :selected, rather than *all* of them.
        if( $('option[value="car"], option[value="motorcycle"], option[value="hgv"], option[value="other"]').is(':selected') ) {
            $('.vehicle-registration-number').slideDown();
        } else {
            $('.vehicle-registration-number').slideUp();
        }
    }).change(); // and call on page load

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

    // Deal with toggling stats19 data on and off on the /around page
    var $stats19Link = $('#stats-19');
    var showText = 'Show reports from the Department of Transport';
    var hideText = 'Hide reports from the Department of Transport';
    var toggleStats19Link = function toggleStats19Link($link){
      if ($link.data('show-stats19')) {
        $link.data({'show-stats19': 0});
        $link.html(hideText);
      } else {
        $link.data({'show-stats19': 1});
        $link.html(showText);
      }
    };
    if (window.fixmystreet.show_stats19 === '1') {
      // Force a load of the pins with the stats_19 param set up on first
      // load because FMS' default _onload function won't know about it.
      window.fixmystreet.markers.protocol.options.params.show_stats19 = '1';
      window.fixmystreet.markers.refresh( { force: true } );
      // Initialise the data variable we use to keep track of whether
      // stats19 data is being shown
      toggleStats19Link();
    } else {
      // Initialise the data variable we use to keep track of whether
      // stats19 data is being shown
      $stats19Link.data({'show-stats19': 1});
    }
    // Handle future clicks on the stats19 link
    $stats19Link.click(function(e) {
      e.preventDefault();
      window.fixmystreet.markers.setVisibility(true);
      window.fixmystreet.markers.protocol.options.params.show_stats19 = $stats19Link.data('show-stats19');
      window.fixmystreet.markers.refresh( { force: true } );
      toggleStats19Link($stats19Link);
      return false;
    });

});
