window.addEventListener("pagehide", function() {
    $('form.waste input[type="submit"]')
        .prop('disabled', false)
        .parents('.govuk-form-group').removeClass('loading');
});
$(function() {
    $('form.waste').on('submit', function(e) {
        var $btn = $('input[type="submit"]', this);
        $btn.prop("disabled", true);
        $btn.parents('.govuk-form-group').addClass('loading');
    });

    var costs = $('.js-bin-costs'),
        cost = costs.data('per_bin_cost') / 100,
        per_new_bin_first_cost = costs.data('per_new_bin_first_cost') / 100,
        per_new_bin_cost = costs.data('per_new_bin_cost') / 100,
        pro_rata_bin_cost = costs.data('pro_rata_bin_cost') / 100;
    function bin_cost_new() {
      var total_bins = parseInt($('#bins_wanted').val() || 0);
      var existing_bins = parseInt($('#current_bins').val() || 0);
      var new_bins = total_bins - existing_bins;
      var total_per_year = total_bins * cost;
      var admin_fee = 0;
      if (new_bins > 0 && per_new_bin_first_cost) {
          admin_fee += per_new_bin_first_cost;
          if (new_bins > 1) {
              admin_fee += (new_bins-1) * per_new_bin_cost;
          }
      }
      var total_cost = total_per_year + admin_fee;

      $('#cost_pa').text(total_per_year.toFixed(2));
      $('#cost_now').text(total_cost.toFixed(2));
      $('#cost_now_admin').text(admin_fee.toFixed(2));
    }
    $('#subscribe_details #bins_wanted, #subscribe_details #current_bins').on('change', bin_cost_new);
    $('#renew #bins_wanted, #renew #current_bins').on('change', bin_cost_new);

    function modify_cost() {
      var total_bins = parseInt($('#bins_wanted').val() || 0);
      var existing_bins = parseInt($('#current_bins').val() || 0);
      var new_bins = total_bins - existing_bins;
      var pro_rata_cost = 0;
      var total_per_year = total_bins * cost;
      var admin_fee = 0;
      var new_bin_text = new_bins == 1 ? 'bin' : 'bins';
      $('#new_bin_text').text(new_bin_text);

      if ( new_bins > 0) {
          $('#new_bin_count').text(new_bins);
          pro_rata_cost = new_bins * pro_rata_bin_cost;
          if (per_new_bin_first_cost) {
              admin_fee += per_new_bin_first_cost;
              if (new_bins > 1) {
                  admin_fee += (new_bins-1) * per_new_bin_cost;
              }
          }
          pro_rata_cost += admin_fee;
      } else {
          $('#new_bin_count').text(0);
      }
      $('#cost_per_year').text(total_per_year.toFixed(2));
      $('#cost_now_admin').text(admin_fee.toFixed(2));
      $('#pro_rata_cost').text(pro_rata_cost.toFixed(2));
    }
    $('#modify #bins_wanted, #modify #current_bins').on('change', modify_cost);
});

// Bulky waste

$(function() {

    var numItemsVisible = $('.bulky-item-wrapper:visible').length;
    var maxNumItems = $('.bulky-item-wrapper').length;
    var itemSelectionCounter = 0;
    var firstItem = $('.bulky-item-wrapper').first();

    function disableAddItemButton() {
        // It will disable button if the first item is empty and the max number of items has been reached.
        if (numItemsVisible == maxNumItems || $('.bulky-item-wrapper').first().find('ul.autocomplete__menu').children().length == 0) {
            $("#add-new-item").prop('disabled', true);
        } else {
            $("#add-new-item").prop('disabled', false);
        }
    }

    $('.govuk-select[name^="item_"]').change(function(e) {
        var $this = $(this);
        disableAddItemButton();

        // To display message if option has a data-extra message
        var valueAttribute = $this.find('option').filter(':selected').data('extra');
        valueAttribute = valueAttribute ? valueAttribute.message : '';
        if (valueAttribute) {
            $this.closest('.bulky-item-wrapper').find('.item-message').text(valueAttribute);
            $this.closest('.bulky-item-wrapper').find('.bulky-item-message').css('display', 'flex');
        } else {
            $this.closest('.bulky-item-wrapper').find('.bulky-item-message').hide();
        }

        // Update total
        var total = 0;
        $('.govuk-select[name^="item_"]').each(function(i, e) {
            var extra = $(this).find('option').filter(':selected').data('extra');
            var price = extra ? parseFloat(extra.price) : 0;
            total += price;
        });
        $('#js-bulky-total').text((total / 100).toFixed(2));
    });

    // If page reloads reveals any wrapper with an item already selected.
    $( '.bulky-item-wrapper' ).each(function() {
       if ($(this).find('ul.autocomplete__menu').children().length > 0) {
            itemSelectionCounter++;
        }
    });

    if (itemSelectionCounter == 0) {
        firstItem.show();
    } else {
        $( '.bulky-item-wrapper' ).each(function() {
            var addedItems = $(this).find('ul.autocomplete__menu');
            if (addedItems.children().length > 0 ) {
                $(this).show();
                numItemsVisible = $('.bulky-item-wrapper:visible').length;
            } else {
                $(this).hide();
                firstItem.show();
            }
        });
    }

    disableAddItemButton();

    // Check if current item has a message. Useful when the user refresh the page
    $( '.bulky-item-wrapper' ).each(function() {
        var $this = $(this);
        var label = $this.find('.autocomplete__option').text();
        var match = $this.find('.js-autocomplete').children("option").filter(function () {return $(this).html() == label; });
        var value = match.val();
        var matchExtra = match.data('extra');
        var itemMessage = matchExtra ? matchExtra.message : '';
        if (itemMessage) {
            $this.find('#item-message').text(itemMessage);
            $this.find('.bulky-item-message').css('display', 'flex');
        } else {
            $this.find('.bulky-item-message').hide();
        }
    });

    // Add items
    $("#add-new-item").click(function(){
        var firstHidden = $('#item-selection-form > .bulky-item-wrapper:hidden:first');
        var hiddenInput = firstHidden.find('input.autocomplete__input');
        firstHidden.show();
        hiddenInput.focus(); // To make it friendly to screen readers
        numItemsVisible = $('.bulky-item-wrapper:visible').length;
        $("#add-new-item").prop('disabled', true);
    });

    //Erase bulky item
    //https://github.com/OfficeForProductSafetyAndStandards/product-safety-database/blob/master/app/assets/javascripts/autocomplete.js#L40
    $(".delete-item").click(function(){
        var $enhancedElement = $(this).closest('.bulky-item-wrapper').find('.autocomplete__input');
        $(this).closest('.bulky-item-wrapper').hide();
        $enhancedElement.val('');
        $(this).closest('.bulky-item-wrapper').find('select.js-autocomplete').val('');
        numItemsVisible = $('.bulky-item-wrapper:visible').length;
        disableAddItemButton();
    });

});
