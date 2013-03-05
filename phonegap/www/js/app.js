var tpl = {

    // Hash of preloaded templates for the app
    templates:{},

    // Recursively pre-load all the templates for the app.
    // This implementation should be changed in a production environment. All the template files should be
    // concatenated in a single file.
    loadTemplates:function (names, callback) {

        var that = this;

        var loadTemplate = function (index) {
            var name = names[index];
            console.log('Loading template: ' + name + ', index: ' + index);
            $.get('templates/en/' + name + '.html', function (data) {
                that.templates[name] = data;
                index++;
                if (index < names.length) {
                    loadTemplate(index);
                } else {
                    callback();
                }
            });
        };

        loadTemplate(0);
    },

    // Get template by name from hash of preloaded templates
    get:function (name) {
        return this.templates[name];
    }

};


;(function (FMS, Backbone, _, $) {
    _.extend(FMS, {
        templates: [
            'home', 'around', 'photo', 'details', 'submit', 'sent'
        ],

        initialized: 0,
        users: new FMS.Users(),
        currentUser: null,
        currentLocation: null,

        currentReport: new FMS.Report(),

        reportToView: null,

        initialize: function () {
            if ( this.initialized == 1 ) {
                return this;
            }
            FMS.initialized = 1;
            tpl.loadTemplates( FMS.templates, function() {
                _.extend(FMS, {
                    router: new FMS.appRouter()
                });

                // we only ever have the details of one user
                FMS.users.fetch();
                if ( FMS.users.length > 0 ) {
                    FMS.currentUser = FMS.users.get(1);
                }
                if ( !FMS.currentUser ) {
                    FMS.currentUser = new FMS.User({id: 1});
                }

                document.addEventListener('backbutton', function() { FMS.router.back(); }, true);

                Backbone.history.start();
                navigator.splashscreen.hide();
            });
        }
    });
})(FMS, Backbone, _, $);

var androidStartUp = function() {
    // deviceready does not fire on some android versions very reliably so
    // we do this instead

    if (FMS.initialized === 1) {
        return;
    }

    if ( typeof device != 'undefined' ) {
        if ( device.platform == 'Android' ) {
            FMS.initialize();
        }
    } else {
        window.setTimeout( androidStartUp, 1000 );
    }
}

document.addEventListener('deviceready', FMS.initialize, false);
window.setTimeout( androidStartUp, 2000 );
