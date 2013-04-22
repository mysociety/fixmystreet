(function (FMS, Backbone, _, $) {
    _.extend( FMS, {
        ExistingView: FMS.FMSView.extend({
            template: 'existing',
            id: 'existing',

            events: {
                'pagehide': 'destroy',
                'pageshow': 'afterDisplay',
                'click #use_report': 'useReport',
                'click #save_report': 'saveReport',
                'click #discard': 'discardReport'
            },

            useReport: function() {
                FMS.setCurrentDraft(this.model);
                this.navigate('around');
            },

            saveReport: function() {
                FMS.clearCurrentDraft();
                this.navigate('around');
            },

            discardReport: function() {
                var reset = FMS.removeDraft(this.model.id, true);
                var that = this;
                reset.done( function() { that.onDraftRemove(); } );
            },

            onDraftRemove: function() {
                FMS.clearCurrentDraft();
                this.navigate( 'around', 'left' );
            }
        })
    });
})(FMS, Backbone, _, $);
