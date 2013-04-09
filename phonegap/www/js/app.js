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


(function (FMS, Backbone, _, $) {
    _.extend(FMS, {
        templates: [
            'home', 'around', 'address_search', 'existing', 'photo', 'details', 'submit', 'submit_email', 'submit_name', 'submit_password', 'sent'
        ],

        initialized: 0,
        users: new FMS.Users(),
        currentUser: null,
        currentLocation: null,
        currentPosition: null,

        currentDraft: new FMS.Draft(),
        allDrafts: new FMS.Drafts(),

        reportToView: null,

        saveCurrentDraft: function() {
            FMS.router.pause();
            FMS.allDrafts.add( FMS.currentDraft );
            FMS.currentDraft.save();
            localStorage.currentDraftID = FMS.currentDraft.id;
        },

        loadCurrentDraft: function() {
            if ( localStorage.currentDraftID && localStorage.currentDraftID != 'null' ) {
                var r = FMS.allDrafts.get( localStorage.currentDraftID );
                if ( r ) {
                    FMS.currentDraft = r;
                }
            }
            localStorage.currentDraftID = null;
        },

        initialize: function () {
            if ( this.initialized == 1 ) {
                return this;
            }
            FMS.initialized = 1;
            tpl.loadTemplates( FMS.templates, function() {
                _.extend(FMS, {
                    router: new FMS.appRouter(),
                    locator: new FMS.Locate()
                });
                _.extend( FMS.locator, Backbone.Events );

                // we only ever have the details of one user
                FMS.users.fetch();
                if ( FMS.users.length > 0 ) {
                    FMS.currentUser = FMS.users.get(1);
                }
                if ( !FMS.currentUser ) {
                    FMS.currentUser = new FMS.User({id: 1});
                }

                document.addEventListener('pause', function() { FMS.saveCurrentDraft(); }, false);
                document.addEventListener('resume', function() { FMS.loadCurrentDraft(); }, false);
                document.addEventListener('backbutton', function() { FMS.router.back(); }, true);

                FMS.allDrafts.fetch();
                FMS.loadCurrentDraft();

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
};

document.addEventListener('deviceready', FMS.initialize, false);
window.setTimeout( androidStartUp, 2000 );
