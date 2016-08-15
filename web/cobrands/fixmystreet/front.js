yepnope.addPrefix( 'preload', function ( resource ) {
    resource.noexec = true;
    return resource;
});

(function(){
    var scripts = document.getElementById('script_front').getAttribute('data-scripts').split(',');
    for (var i=0; i<scripts.length; i++) {
        scripts[i] = 'preload!' + scripts[i];
    }
    yepnope({ load: scripts });
})();
