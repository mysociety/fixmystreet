$(function() {
    $('form.waste input[type="submit"]').prop('disabled', false);
    $('form.waste').on('submit', function(e) {
        var $btn = $('input[type="submit"]', this);
        $btn.prop("disabled", true);
        $btn.parents('.govuk-form-group').addClass('loading');
    });

    var cost = $('#per_bin_cost').val();
    function bin_cost_new() {
      var total_bins = parseInt($('#bins_wanted').val() || 0);
      var total_cost = ( total_bins * cost ) / 100;
      $('#cost_pa').text(total_cost.toFixed(2));
      $('#cost_now').text(total_cost.toFixed(2));
    }
    $('#subscribe_details #bins_wanted').on('change', bin_cost_new);
    $('#renew #bins_wanted').on('change', bin_cost_new);

    function modify_cost() {
      var total_bins = parseInt($('#bins_wanted').val() || 0);
      var existing_bins = parseInt($('#current_bins').val() || 0);
      var new_bins = total_bins - existing_bins;
      var pro_rata_cost = 0;
      var total_cost = ( total_bins * cost ) / 100;
      var new_bin_text = new_bins == 1 ? 'bin' : 'bins';
      $('#new_bin_text').text(new_bin_text);

      if ( new_bins > 0) {
          $('#new_bin_count').text(new_bins);
          pro_rata_cost = ( new_bins * parseInt($('#pro_rata_bin_cost').val()) ) / 100;
      } else {
          $('#new_bin_count').text(0);
      }
      $('#cost_per_year').text(total_cost.toFixed(2));
      $('#pro_rata_cost').text(pro_rata_cost.toFixed(2));
    }
    $('#modify #bins_wanted').on('change', modify_cost);
});
