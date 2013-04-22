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
                localStorage.currentDraftID = FMS.currentDraft.id;
                this.navigate('around');
            },

            saveReport: function() {
                localStorage.currentDraftID = null;
                FMS.currentDraft = new FMS.Draft();
                this.navigate('around');
            },

            discardReport: function() {
                var reset = FMS.removeDraft(FMS.currentDraft.id, true);
                var that = this;
                reset.done( function() { that.onDraftRemove(); } );
            },

            onDraftRemove: function() {
                this.navigate( 'around', 'left' );
            }
        })
    });
})(FMS, Backbone, _, $);
