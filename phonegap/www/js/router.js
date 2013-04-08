(function (FMS, Backbone, _, $) {
    _.extend(FMS, {
        appRouter: Backbone.Router.extend({
            currentView: null,

            routes: {
                '': 'home',
                'home': 'home',
                'around': 'around',
                'search': 'search',
                'photo': 'photo',
                'details': 'details',
                'submit': 'submit',
                'submit-email': 'submitEmail',
                'submit-name': 'submitName',
                'submit-password': 'submitPassword',
                'sent': 'sent'
            },

            initialize: function() {
            },

            pause: function() {
                if (this.currentView && this.currentView.updateCurrentReport) {
                    this.currentView.updateCurrentReport();
                }
            },

            back: function() {
                if (this.currentView && this.currentView.prev) {
                    this.currentView.onClickButtonPrev();
                }
            },

            around: function(){
                var aroundView = new FMS.AroundView({ model: FMS.currentReport });
                this.changeView(aroundView);
            },

            search: function(){
                var searchView = new FMS.SearchView({ model: FMS.currentReport, msg: FMS.searchMessage });
                this.changeView(searchView);
            },

            home: function(){
                var homeView = new FMS.HomeView({ model: FMS.currentReport });
                this.changeView(homeView);
            },

            photo: function(){
                var photoView = new FMS.PhotoView({ model: FMS.currentReport });
                this.changeView(photoView);
            },

            details: function(){
                var detailsView = new FMS.DetailsView({ model: FMS.currentReport });
                this.changeView(detailsView);
            },

            submit: function(){
                var submitView = new FMS.SubmitView({ model: FMS.currentReport });
                this.changeView(submitView);
            },

            submitEmail: function(){
                var submitEmailView = new FMS.SubmitEmailView({ model: FMS.currentReport });
                this.changeView(submitEmailView);
            },

            submitName: function(){
                var submitNameView = new FMS.SubmitNameView({ model: FMS.currentReport });
                this.changeView(submitNameView);
            },

            submitPassword: function(){
                var submitPasswordView = new FMS.SubmitPasswordView({ model: FMS.currentReport });
                this.changeView(submitPasswordView);
            },

            sent: function(){
                var sentView = new FMS.SentView({ model: FMS.currentReport });
                this.changeView(sentView);
            },

            changeView: function(view) {
                console.log( 'change View to ' + view.id );
                $(view.el).attr('data-role', 'page');
                if ( view.prev ) {
                    $(view.el).attr('data-add-back-btn', 'true');
                }
                view.render();
                $('body').append($(view.el));
                $.mobile.changePage($(view.el), { changeHash: false });

                console.log('changed View to ' + view.id);
                this.currentView = view;
            }
        })
    });
})(FMS, Backbone, _, $);
