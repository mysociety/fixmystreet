window.garden_waste_first_bin_discount_applies = function() {
    return $('input[name="payment_method"]:checked').val() === 'direct_debit';
};

$(function() {
    $('#subscribe_details input[name="payment_method"]').on('change', window.garden_waste_bin_cost_new);
    $('#modify input[name="payment_method"]').on('change', window.garden_waste_modify_cost);
});
