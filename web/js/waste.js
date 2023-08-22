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

(function(){
    var maxNumItems;

    function disableAddItemButton() {
        // It will disable button if the first item is empty or the max number of items has been reached.
        var numItemsVisible = $('.bulky-item-wrapper:visible').length;
        if (numItemsVisible == maxNumItems || !$('.bulky-item-wrapper').first().find('select').val()) {
            $("#add-new-item").prop('disabled', true);
        } else {
            $("#add-new-item").prop('disabled', false);
        }
    }

    function updateTotal() {
        var totalId = $('#js-bulky-total');
        if (!totalId.length) {
            // No price section, could be free collection
            return;
        }
        var pricing = totalId.data('pricing');
        // Update total
        var total = 0;
        if (pricing.strategy === 'per_item') {
            $('.govuk-select[name^="item_"] option:selected').each(function(i, e) {
                var extra = $(this).data('extra');
                var price = extra ? parseFloat(extra.price) : 0;
                if (!isNaN(price)) {
                    total += price;
                }
            });
            totalId.text((total / 100).toFixed(2));
        } else if (pricing.strategy === 'banded') {
            var count = 0;
            $('.govuk-select[name^="item_"] option:selected').each(function(i, e) {
                if ($(this).val()) {
                    count++;
                }
            });
            for (var i=0; i<pricing.bands.length; i++) {
                if (count <= pricing.bands[i].max) {
                    total = pricing.bands[i].price;
                    break;
                }
            }
            totalId.text((total / 100).toFixed(2));
        }
    }

    function update_extra_message(select) {
        var data = select.find('option').filter(':selected').data('extra');
        data = data ? data.message : '';
        var wrapper = select.closest('.bulky-item-wrapper');
        if (data) {
            wrapper.find('.item-message').text(data);
            wrapper.find('.bulky-item-message').css('display', 'flex');
        } else {
            wrapper.find('.bulky-item-message').hide();
        }
    }

    $(function() {
        maxNumItems = $('.bulky-item-wrapper').length;

        $('.govuk-select[name^="item_"]').change(function(e) {
            var $this = $(this);
            disableAddItemButton();
            // To display message if option has a data-extra message
            update_extra_message($this);
            updateTotal();
        });

        // Add items
        $("#add-new-item").click(function(){
            var firstHidden = $('#item-selection-form > .bulky-item-wrapper:hidden:first');
            var hiddenInput = firstHidden.find('input.autocomplete__input');
            firstHidden.show();
            hiddenInput.focus(); // To make it friendly to screen readers
            $("#add-new-item").prop('disabled', true);
        });

        //Erase bulky item
        //https://github.com/OfficeForProductSafetyAndStandards/product-safety-database/blob/master/app/assets/javascripts/autocomplete.js#L40
        $(".delete-item").click(function(){
            var $wrapper = $(this).closest('.bulky-item-wrapper');
            var $enhancedElement = $wrapper.find('.autocomplete__input');
            $wrapper.hide();
            $enhancedElement.val('');
            $wrapper.find('select.js-autocomplete').val('');
            disableAddItemButton();
            updateTotal();
        });

        if (fixmystreet.cobrand == 'brent') {
            update_small_items_other_notes = function() {
                var $this = $(this);
                var $notes = $this.closest('.bulky-item-wrapper').find('[id^="form-item_notes_"]');
                if ($this.val() == 'Small electricals: Other item under 30x30x30 cm') {
                    $notes.show();
                } else {
                    $notes.hide();
                }
            };
            $('.govuk-select[name^="item_"]').change(update_small_items_other_notes);
            $('.govuk-select[name^="item_"]').each(update_small_items_other_notes);
        }

    });

    window.addEventListener("pageshow", function(e){
        // If page reloads reveals any wrapper with an item already selected.
        $( '.bulky-item-wrapper' ).each(function() {
            var $wrapper = $(this),
                select = $wrapper.find('select'),
                value = select.val();
            if (value) {
                $wrapper.show();
                // If we do it immediately, it remains blank in Safari, I think
                // some interaction with the 100ms polling in the autocomplete
                // to spot changes to the value
                setTimeout(function() {
                    $wrapper.find('.autocomplete__wrapper input').val(value);
                }, 110);
                update_extra_message(select);
            } else {
                $wrapper.hide();
                $('.bulky-item-wrapper').first().show();
            }
        });

        updateTotal();
        disableAddItemButton();
    });
})();
