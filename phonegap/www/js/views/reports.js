(function (FMS, Backbone, _, $) {
    _.extend( FMS, {
        ReportsView: FMS.FMSView.extend({
            template: 'reports',
            id: 'reports',
            next: 'home',

            events: {
                'pagehide': 'destroy',
                'pagebeforeshow': 'beforeDisplay',
                'pageshow': 'afterDisplay',
                'vclick .del_report': 'deleteReport',
                'vclick .use_report': 'useReport',
                'vclick .ui-btn-left': 'onClickButtonPrev',
                'vclick .ui-btn-right': 'onClickButtonNext'
            },

            deleteReport: function(e) {
                var el = $(e.target);
                var id = el.parent('li').attr('id');
                var del = FMS.removeDraft( id, true );
                var that = this;
                del.done( function() { that.onRemoveDraft(el); } );
                del.fail( function() { that.onRemoveDraft(el); } );
            },

            useReport: function(e) {
                var el = $(e.target);
                var id = el.parent('li').attr('id');
                FMS.currentDraft = FMS.allDrafts.get(id);
                this.navigate('around');
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
