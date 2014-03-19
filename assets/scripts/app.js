function replace_str(base, replacement) {
  return base + replacement; // FIXME TODO should replace %s
}

$(function(){

  $('.reveal-on-click dd').hide();
  $('.reveal-on-click dt').on('click', function(){
    // $(this).find('+ dd').toggle();
    var $dd = $(this).find('+ dd');
    if ($dd.is(':visible')) {
      $(this).removeClass('revealed');
      $dd.slideUp();
    } else {
      $(this).addClass('revealed');
      $dd.slideDown();
    }
  });

  var reveal_all_text = {'reveal': 'Show all ', 'hide': 'Collapse all '}; // TODO add %s

  $('dl.reveal-on-click').each(function(){
    $(this).before("<div class='reveal-all revealed'>&nbsp;</div>");
  });
  $('.reveal-all').on('click', function(){
    console.log("reveal all clicked");
    var $dl = $(this).find('+ dl.reveal-on-click');
    var noun = $dl.data('reveal-noun');
    if ($(this).hasClass('revealed')) {
      console.log("hiding all");
      $dl.find('dt').removeClass('revealed');
      $dl.find('dd').slideUp();
      $(this).removeClass('revealed');
      $(this).text(replace_str(reveal_all_text['reveal'], noun));
    } else {
      console.log("showing all");
      $dl.find('dt').addClass('revealed');
      $dl.find('dd').slideDown();
      $(this).addClass('revealed');
      $(this).text(replace_str(reveal_all_text['hide'], noun));
    }
  });
  $('.reveal-all').trigger('click');


  /**
   * Owl Slider
   */
  $("#owl-slide").owlCarousel({
    items : 1,
    singleItem : true,
    navigation : true
  });
});
