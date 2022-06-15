(function(){

  if (!fixmystreet.maps) {
      return;
  }

  function getBodies() {
    var bucks, parish;
    $.each(fixmystreet.bodies, function(i, body) {
      if (body === 'Buckinghamshire Council') {
        bucks = body;
      } else {
        parish = body;
      }
    });

    return {
      bucks: bucks,
      parish: parish
    };
  }

  $(function() {

    $(document).on('change', '#form_speed_limit_greater_than_30', function(e) {
      var bodies = getBodies();
      if (!bodies.bucks || !bodies.parish) {
        return;
      }

      if ($(this).val() === 'no') {
        // Report for the parish
        fixmystreet.update_public_councils_text($('#js-councils_text').html(), [bodies.parish]);
      } else {
        // Report for the council
        fixmystreet.update_public_councils_text($('#js-councils_text').html(), [bodies.bucks]);
      }
    });

    $(fixmystreet).on('report_new:category_change', function(e) {
      var bodies = getBodies();
      if (!bodies.parish) {
        return;
      }

      fixmystreet.update_public_councils_text($('#js-councils_text').html(), [bodies.parish]);
    });
  });

})();
