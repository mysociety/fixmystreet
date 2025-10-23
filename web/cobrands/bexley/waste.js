window.garden_waste_first_bin_discount_applies = function() {
    var costs = $('.js-bin-costs'),
        payment_method = costs.data('payment_method');

    return payment_method === 'direct_debit' || $('input[name="payment_method"]:checked').val() === 'direct_debit';
};

$(function() {
    // If there's an error when submitting the subscribe form,
    // the first bin discount won't be displayed even when it should apply.
    // This is due to how the form is set-up on the server.
    // We work around this by just checking if the discount should apply
    // when the page loads and running the cost calculation function if so.
    window.onload = function() {
        if (window.garden_waste_first_bin_discount_applies()) {
            window.garden_waste_bin_cost_new();
        }
    };
    $('#subscribe_details input[name="payment_method"]').on('change', window.garden_waste_bin_cost_new);
    $('#renew input[name="payment_method"]').on('change', window.garden_waste_bin_cost_new);
});
