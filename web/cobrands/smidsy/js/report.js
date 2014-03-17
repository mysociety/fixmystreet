$(function() {

$( "#form_incident_date" ).datepicker({ 
    minDate: -7, 
    maxDate: +0,
    defaultDate: +0,
    dateFormat: 'dd/mm/yy'
});

var select = $( "#form_severity" );

var slider = $( "<div id='severity-slider'></div>" );

function colour_severity () {
    var val = select.val();
    var idx = select[0].selectedIndex;
    if (val < severity.minor_threshold) {
        slider.addClass('severity-low');
        slider.removeClass('severity-medium');
        slider.removeClass('severity-high');
    }
    else if (val < severity.major_threshold) {
        slider.removeClass('severity-low');
        slider.addClass('severity-medium');
        slider.removeClass('severity-high');
    }
    else {
        slider.removeClass('severity-low');
        slider.removeClass('severity-medium');
        slider.addClass('severity-high');
    }

    console.log( severity, severity.categories, idx );

    $('#severity_description').html( severity.categories[ idx ].description );
}

slider.insertBefore( select ).slider({
    min: 1,
    max: severity.categories.length,
    range: "min",
    value: select[ 0 ].selectedIndex + 1,
    slide: function( event, ui ) {
        select[ 0 ].selectedIndex = ui.value - 1;
        colour_severity();
    }
});

select.change(function() {
    slider.slider( "value", this.selectedIndex + 1 );
    colour_severity();
});

colour_severity();

});
