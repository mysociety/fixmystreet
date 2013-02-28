;(function (FMS, Backbone, _, $) {
    _.extend(FMS, {
        appRouter: Backbone.Router.extend({
            currentView: null,

            routes: {
                '': 'home',
                'home': 'home',
                'around': 'around'
            },

            initialize: function() {
            },

            back: function() {
                if (this.currentView && this.currentView.prev) {
                    this.currentView.onClickButtonPrev();
                }
            },

            around: function(){
                var aroundView = new FMS.AroundView();
                this.changeView(aroundView);
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
                if(!_.isNull(this.currentView)) {
                    var oldView = this.currentView;
                    oldView.destroy();
                }
                view.afterDisplay();
                this.currentView = view;
            }
        })
    });
})(FMS, Backbone, _, $);
