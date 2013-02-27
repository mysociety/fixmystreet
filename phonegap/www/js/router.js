;(function (FMS, Backbone, _, $) {
    _.extend(FMS, {
        appRouter: Backbone.Router.extend({
            currentView: null,

            routes: {
                '': 'home',
                'home': 'home',
            },

            initialize: function() {
            },

            back: function() {
                if (this.currentView && this.currentView.prev) {
                    this.currentView.onClickButtonPrev();
                }
            },

            home: function(){
                var homeView = new FMS.HomeView();
                this.changeView(homeView);
            },

            changeView: function(view) {
                $(view.el).attr('data-role', 'page');
                view.render();
                $('body').append($(view.el));
                $.mobile.changePage($(view.el), { changeHash: false });
                this.currentView = view;
            }
        })
    });
})(FMS, Backbone, _, $);
