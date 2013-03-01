;(function (FMS, Backbone, _, $) {
    _.extend(FMS, {
        appRouter: Backbone.Router.extend({
            currentView: null,

            routes: {
                '': 'home',
                'home': 'home',
                'around': 'around',
                'photo': 'photo',
                'details': 'details'
            },

            initialize: function() {
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
