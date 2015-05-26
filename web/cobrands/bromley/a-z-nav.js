(function($){
  $(function(){
    // TOGGLE MENU
    // Hides the items by default.
    $('.custom-side-nav > ul > li > ul').hide();

    // Stops the toggle links going off to their actual link. Make the links actual links though for non js users.
    $('.custom-side-nav > ul > li > a').click(function(e) {
      e.preventDefault();
      // When an item is clicked this checks to see if any other items are down and strips the class of active and toggles them up.
      if( !$(this).hasClass('active') ) {
        $('.custom-side-nav > ul > li > a.active').removeClass('active')
        .next('ul')
        .slideUp(300);
      }
      // This toggles a class of 'active' on the item in question and toggles the unordered list below it when it is clicked.
      $(this).toggleClass('active')
      .next('ul')
      .slideToggle(300);
    });
  });
})(window.jQuery);