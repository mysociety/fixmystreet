$('.toggle').click(function(e) {
	e.preventDefault();
	$('.toggle span').toggleClass('active');
	$('.list-cols').slideToggle('slow', function() {
	});
	if ($('.toggle span').hasClass('active')) {
		$('.toggle span').html('-');
	} else {
		$('.toggle span').html('+');
	}
})
