(function (FMS, Backbone, _, $) {
    _.extend( FMS, {
        ExistingView: FMS.FMSView.extend({
            template: 'existing',
            id: 'existing',

            events: {
                'pagehide': 'destroy',
                'pageshow': 'afterDisplay',
                'click #use_report': 'useReport',
                'click #discard': 'discardReport'
            },

            useReport: function() {
                localStorage.currentDraftID = FMS.currentDraft.id;
                this.navigate('around');
            },

            discardReport: function() {
                FMS.currentDraft.destroy();
                FMS.currentDraft = new FMS.Draft();
                this.navigate('around');
            }
        })
    });
})(FMS, Backbone, _, $);
