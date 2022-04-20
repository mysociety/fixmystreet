$(function() {
    $('form.waste input[type="submit"]').prop('disabled', false);
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
