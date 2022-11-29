document.body.addEventListener('keydown', function(e) {
    // Using this handler to navigate images in fancybox with
    // arrow keys instead of the built-in one so we can stop the
    // events propagating and moving the map as well.
    if (e.keyCode === 37 || e.keyCode === 39) {
        fancyboxImage = document.getElementById("fancybox-img");
        if (fancyboxImage) {
            e.stopPropagation();
            if (e.keyCode === 37) {
                $.fancybox.prev();
            } else {
                $.fancybox.next();
            }
        }
    }
});

