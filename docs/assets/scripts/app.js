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
      $(this).text(replace_str(reveal_all_text.reveal, noun));
    } else {
      console.log("showing all");
      $dl.find('dt').addClass('revealed');
      $dl.find('dd').slideDown();
      $(this).addClass('revealed');
      $(this).text(replace_str(reveal_all_text.hide, noun));
    }
  });
  $('.reveal-all').trigger('click');

  // hide the attention-box breakouts within mock-documents so 
  // the use can copy-and-paste the templates
  // this is used in: running/example_press_releases
  $('.toggle-button').on('click', function(){
      var target = $(this).data("target");
      $('#' + target +'.mock-document .attention-box').slideToggle();
  });
  $('.toggle-button').show(); // reveal the show/hide buttons

  /**
   * Owl Slider
   */
  $("#owl-slide").owlCarousel({
    items : 1,
    singleItem : true,
    navigation : true
  });


  /**
   * training slideshow for /training pages
   **/
  $('a.play-as-slideshow').html('&raquo; View as slideshow').attr('href', '#');

  var current_slide_number;
  var slides;
  $(".play-as-slideshow").on("click", function(){
      var $slide;
      if (current_slide_number === undefined) {
          slides = [];
          current_slide_number = 0;
          $slide = $(
            '<div id="full-screen-slide" class="modal-slide">' +
              '<div>' +
                '<div class="slide-contents"></div>' +
                '<a href="#close" title="Close" class="modal-slide-close">&times;</a>' +
              '</div>' +
            '</div>');
          $('body').prepend($slide);
          $(".modal-slide-close").on("click", function(){
              end_training_slides();
          });
          var slides_title = $('.main-content h1').text();
          var $slide_0 = $('<div class="slide-contents">' +
              '<h2>' + slides_title + '</h2>' +
              '<p>press &rarr; to advance</p>' +
              '<p>press esc to exit</p>' +
          '</div>');
          slides.push($slide_0);
          var last_heading = "";
          $("main.main-content").find("h2,h3").each(function($i){
              last_heading = $(this).html();
              var $contents = $(this).nextUntil("h2,h3");
              var $slide_div = $('<div class="slide-contents"></div>');
              $slide_div.append($("<h2/>").html(last_heading));
              $slide_div.append($contents.clone(false));
              slides.push($slide_div.clone(false));
          });
          $(document).keydown( function(e) { key_down_training(e.which);} );
      }
      display_training_slide(0);
  });  

  
  // which_slide: "next", "prev", or a number
  function display_training_slide(which_slide){
      if (which_slide == 'next' && current_slide_number + 1 < slides.length) {
          current_slide_number++;
      } else if (which_slide == 'prev' && current_slide_number > 0 ) {
          current_slide_number--;
      } else {
          var slide_number = parseInt(which_slide);
          if (slide_number >= 0 && slide_number < slides.length) {
              current_slide_number = slide_number;
          }
      }
      $("#full-screen-slide .slide-contents")
        .html(slides[current_slide_number].html());
      $("#full-screen-slide").show();
  }

  function end_training_slides(){
      $("#full-screen-slide").hide();
      current_slide_number = 0;
  }

  var key_code_arrow_left = 37;
  var key_code_arrow_right = 39;
  var key_code_ENTER = 13;
  var key_code_ESC = 27;
  var key_code_SPACE = 32;
  var key_code_0 = 48;
  var key_code_9 = 57;
  var key_code_B = 66;
  
  function key_down_training(key_code){
    if (key_code == key_code_arrow_right || key_code == key_code_ENTER) {
        display_training_slide('next');
    } else if (key_code == key_code_arrow_left || key_code == key_code_B ) {
        display_training_slide('prev');
    } else if (key_code >= key_code_0 && key_code <= key_code_9) {
        display_training_slide(key_code - key_code_0);
    } if (key_code == key_code_ESC || key_code == key_code_SPACE) {
        end_training_slides();
    }
  }


 
});
