(function (FMS, Backbone, _, $) {
    _.extend( FMS, {
        ReportsView: FMS.FMSView.extend({
            template: 'reports',
            id: 'reports',
            next: 'home',

            events: {
                'pagehide': 'destroy',
                'pageshow': 'afterDisplay',
                'click .del_report': 'deleteReport',
                'click .ui-btn-left': 'onClickButtonPrev',
                'click .ui-btn-right': 'onClickButtonNext'
            },

            deleteReport: function(e) {
                var el = $(e.target);
                var del = FMS.removeDraft( el.attr('id'), true );
                var that = this;
                del.done( function() { that.onRemoveDraft(el); } );
            },

            onRemoveDraft: function(el) {
                el.parent('li').remove();
            },

            render: function(){
                if ( !this.template ) {
                    console.log('no template to render');
                    return;
                }
                template = _.template( tpl.get( this.template ) );
                if ( this.model ) {
                    this.$el.html(template({ model: this.model.toJSON(), drafts: FMS.allDrafts }));
                } else {
                    this.$el.html(template());
                }
                this.afterRender();
                return this;
            }
        })
    });
})(FMS, Backbone, _, $);
