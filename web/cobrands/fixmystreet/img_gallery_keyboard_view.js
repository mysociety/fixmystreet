document.querySelector('.alerts__nearby-activity__photos').addEventListener('focus', function(e) {
    if (e.target.tagName === 'A') {
        e.target.scrollIntoView();
    }
}, true);
