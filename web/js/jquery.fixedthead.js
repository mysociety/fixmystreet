/*
 * jQuery.fixedThead.js
 * By Zarino at mySociety
 */

(function ($) {

  // Call this on a <thead> element and it'll be given a class
  // of '.js-fixed-thead__clone' when you scroll down. eg:
  //   $('#my-table thead').fixedThead()
  //
  // You'll probably want to specify some CSS styles like:
  //   .js-fixed-thead__clone { position: fixed; background: #fff; }

  $.fn.fixedThead = function() {

    var calculateCloneDimensions = function calculateCloneDimensions($originalThead, $cloneThead){
      $cloneThead.css({
        width: $originalThead.width()
      });

      $('tr', $originalThead).each(function(tr_index, tr){
        $('th', tr).each(function(th_index, th){
          $cloneThead.find('tr:eq(' + tr_index + ') th:eq(' + th_index + ')').css({
            width: $(th).width()
          });
        });
      });
    }

    var showOrHideClone = function showOrHideClone($table, $originalThead, $cloneThead){
      var bounds = $table[0].getBoundingClientRect();

      // First we detect whether *any* of the table is visible,
      // then, if it is, we position the fixed thead so that it
      // never extends outside of the table bounds even when the
      // visible portion of the table is shorter than the thead.

      if(bounds.top <= 0 && bounds.bottom >= 0){
        $cloneThead.css('display', $originalThead.css('display'));

        var rowHeight = $cloneThead.outerHeight();
        if(bounds.bottom < rowHeight){
          $cloneThead.css({
            top: (rowHeight - bounds.bottom) * -1
          });
        } else {
          $cloneThead.css({
            top: 0
          });
        }

      } else {
        $cloneThead.css('display', 'none');
      }
    }

    return this.each(function() {
      var $originalThead = $(this);
      var $table = $originalThead.parent('table');
      var $cloneThead = $originalThead.clone().addClass('js-fixed-thead__clone');

      $cloneThead.insertAfter($originalThead);
      $cloneThead.css('display', 'none');

      calculateCloneDimensions($originalThead, $cloneThead);
      showOrHideClone($table, $originalThead, $cloneThead);

      $(window).resize(function(){
        calculateCloneDimensions($originalThead, $cloneThead);
        showOrHideClone($table, $originalThead, $cloneThead);
      });

      $(window).scroll(function(){
        showOrHideClone($table, $originalThead, $cloneThead);
      });
    });

  };

}(jQuery));
