// jshint esversion: 6

(function(){
    if (!('IntersectionObserver' in window)) {
        return;
    }

    // Now we're here, we can assume quite modern JavaScript!

    const observer = new IntersectionObserver(onIntersection, {
        rootMargin: "50px 0px"
    });

    const images = document.querySelectorAll(".js-lazyload");
    images.forEach(image => {
        observer.observe(image);
    });

    function onIntersection(entries, observer) {
        entries.forEach(entry => {
            if (entry.intersectionRatio > 0) {
                // Loading the image is the only thing we care about, so can
                // stop observing.
                observer.unobserve(entry.target);
                // Removing this class (which is suppressing background-image)
                // will trigger the image load
                entry.target.classList.remove('js-lazyload');
            }
        });
    }
})();
