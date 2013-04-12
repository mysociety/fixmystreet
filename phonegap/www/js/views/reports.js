(function (FMS, Backbone, _, $) {
    _.extend( FMS, {
        ReportsView: FMS.FMSView.extend({
            template: 'reports',
            id: 'reports',
            next: 'home',

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
