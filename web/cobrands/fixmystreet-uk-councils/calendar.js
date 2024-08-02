(function(){
    var userAgent = navigator.userAgent,
        os = 'pc';
    if (userAgent.indexOf('Mobi') > -1) os = 'phone';
    else if (userAgent.indexOf('Mac') > -1) os = 'mac';
    document.documentElement.classList.add('os-' + os);
})();

document.addEventListener('clipboard-copy', function(event) {
    var t = event.target;
    t.textContent = 'Copied!';
    document.getElementById('ics-announce').setAttribute('aria-label', 'Copied');
});
