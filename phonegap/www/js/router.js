(function (FMS, Backbone, _, $) {
    _.extend(FMS, {
        appRouter: Backbone.Router.extend({
            currentView: null,
            reverse: false,

            routes: {
                '': 'home',
                'home': 'home',
                'offline': 'offline',
                'around': 'around',
                'search': 'search',
                'existing': 'existing',
                'photo': 'photo',
                'details': 'details',
                'details_extra': 'details_extra',
                'submit-start': 'submitStart',
                'submit': 'submit',
                'submit-email': 'submitEmail',
                'submit-name': 'submitName',
                'submit-name-set-password': 'submitNameSetPassword',
                'submit-password': 'submitPassword',
                'submit-set-password': 'submitSetPassword',
                'save_offline': 'saveOffline',
                'sent': 'sent',
                'reports': 'reports',
                'login': 'login'
            },

            initialize: function() {
            },

            pause: function() {
                if (this.currentView && this.currentView.updateCurrentDraft) {
                    this.currentView.updateCurrentDraft();
                }
            },

            back: function() {
                if (this.currentView && this.currentView.prev) {
                    this.currentView.onClickButtonPrev();
                }
            },

            reverseTransition: function() {
                this.reverse = true;
            },

            around: function(){
                var aroundView = new FMS.AroundView({ model: FMS.currentDraft });
                this.changeView(aroundView);
            },

            search: function(){
                var searchView = new FMS.SearchView({ model: FMS.currentDraft, msg: FMS.searchMessage });
                this.changeView(searchView);
            },

            existing: function(){
                var existingView = new FMS.ExistingView({ model: FMS.currentDraft });
                this.changeView(existingView);
            },

            home: function(){
                var homeView = new FMS.HomeView({ model: FMS.currentDraft });
                this.changeView(homeView);
            },

            offline: function() {
                var offlineView = new FMS.OfflineView({ model: FMS.currentDraft });
                this.changeView(offlineView);
            },

            photo: function(){
                var photoView = new FMS.PhotoView({ model: FMS.currentDraft });
                this.changeView(photoView);
            },

            details: function(){
                var detailsView = new FMS.DetailsView({ model: FMS.currentDraft });
                this.changeView(detailsView);
            },

            details_extra: function(){
                var detailsExtraView = new FMS.DetailsExtraView({ model: FMS.currentDraft });
                this.changeView(detailsExtraView);
            },

            submitStart: function() {
                var submitView;
                if ( FMS.currentUser && FMS.isLoggedIn ) {
                    submitView = new FMS.SubmitConfirmView({ model: FMS.currentDraft });
                } else {
                    submitView = new FMS.SubmitEmailView({ model: FMS.currentDraft });
                }
                this.changeView(submitView);
            },

            submit: function(){
                var submitView = new FMS.SubmitView({ model: FMS.currentDraft });
                this.changeView(submitView);
            },

            submitEmail: function(){
                var submitEmailView = new FMS.SubmitEmailView({ model: FMS.currentDraft });
                this.changeView(submitEmailView);
            },

            submitName: function(){
                var submitNameView = new FMS.SubmitNameView({ model: FMS.currentDraft });
                this.changeView(submitNameView);
            },

            submitNameSetPassword: function(){
                var submitNameSetPasswordView = new FMS.SubmitNameSetPasswordView({ model: FMS.currentDraft });
                this.changeView(submitNameSetPasswordView);
            },

            submitPassword: function(){
                var submitPasswordView = new FMS.SubmitPasswordView({ model: FMS.currentDraft });
                this.changeView(submitPasswordView);
            },

            submitSetPassword: function(){
                var submitSetPasswordView = new FMS.SubmitSetPasswordView({ model: FMS.currentDraft });
                this.changeView(submitSetPasswordView);
            },

            saveOffline: function(){
                var saveOfflineView = new FMS.SaveOfflineView({ model: FMS.currentDraft });
                this.changeView(saveOfflineView);
            },

            sent: function(){
                var sentView = new FMS.SentView({ model: FMS.currentDraft });
                this.changeView(sentView);
            },

            reports: function() {
                var reportsView = new FMS.ReportsView({ model: FMS.currentDraft });
                this.changeView(reportsView);
            },

            login: function() {
                var loginView = new FMS.LoginView({ model: FMS.currentUser });
                this.changeView(loginView);
            },

            changeView: function(view) {
                console.log( 'change View to ' + view.id );
                $(view.el).attr('data-role', 'page');
                if ( view.prev ) {
                    $(view.el).attr('data-add-back-btn', 'true');
                }
                view.render();
                $('.jquerymobile').append($(view.el));

                // if we are coming from the front page then we don't want to do
                // any transitions as they just add visual distraction to no end
                var options = { changeHash: false };
                if ( !this.currentView || this.currentView.id == 'front-page' ) {
                    options.transition = 'none';
                }
                if ( this.reverse ) {
                    options.reverse = true;
                }
                this.reverse = false;

                $.mobile.changePage($(view.el), options);

                console.log('changed View to ' + view.id);
                this.currentView = view;
            }
        })
    });
})(FMS, Backbone, _, $);
