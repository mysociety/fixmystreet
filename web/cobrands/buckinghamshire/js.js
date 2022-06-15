(function(){

  if (!fixmystreet.maps) {
      return;
  }

  $(function() {
    var bucks, parish;
    $.each(fixmystreet.bodies, function(i, body) {
      if (body === 'Buckinghamshire Council') {
        bucks = body;
      } else {
        parish = body;
      }
    });

    $(document).on('change', '#form_speed_limit_greater_than_30', function(e) {
      if (!bucks || !parish) {
        return;
      }

      if ($(this).val() === 'no') {
        // Report for the parish
        fixmystreet.update_public_councils_text($('#js-councils_text').html(), [parish]);
      } else {
        // Report for the council
        fixmystreet.update_public_councils_text($('#js-councils_text').html(), [bucks]);
      }
    });

    $(fixmystreet).on('report_new:category_change', function(e) {
      if (!parish) {
        return;
      }

      fixmystreet.update_public_councils_text($('#js-councils_text').html(), [parish]);
    });
  });

})();
