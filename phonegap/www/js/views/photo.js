;(function (FMS, Backbone, _, $) {
    _.extend( FMS, {
        PhotoView: FMS.FMSView.extend({
            template: 'photo',
            id: 'photo-page',
            prev: 'around',
            next: 'details',

            events: {
                'pagehide': 'destroy',
                'pageshow': 'afterDisplay',
                'click .ui-btn-left': 'onClickButtonPrev',
                'click .ui-btn-right': 'onClickButtonNext',
                'click #id_photo_button': 'takePhoto',
                'click #id_existing': 'addPhoto',
                'click #id_del_photo_button': 'deletePhoto'
            },

            takePhoto: function() {
                var that = this;
                navigator.camera.getPicture( function(imgURI) { that.addPhotoSuccess(imgURI); }, function(error) { that.addPhotoFail(error); }, { saveToPhotoAlbum: true, quality: 49, destinationType: Camera.DestinationType.FILE_URI, sourceType: navigator.camera.PictureSourceType.CAMERA, correctOrientation: true });
            },

            addPhoto: function() {
                var that = this;
                navigator.camera.getPicture( function(imgURI) { that.addPhotoSuccess(imgURI); }, function(error) { that.addPhotoFail(error); }, { saveToPhotoAlbum: false, quality: 49, destinationType: Camera.DestinationType.FILE_URI, sourceType: navigator.camera.PictureSourceType.PHOTOLIBRARY, correctOrientation: true });
            },

            addPhotoSuccess: function(imgURI) {
                $('#photo').attr('src', imgURI );
                this.model.set('file', imgURI);

                $('#display_photo').show();
                $('#add_photo').hide();
            },

            addPhotoFail: function() {
                if ( message != 'no image selected' &&
                    message != 'Selection cancelled.' &&
                    message != 'Camera cancelled.'
                    ) {
                    this.displayError(FMS.strings.photo_failed);
                }
            },

            deletePhoto: function() {
                this.model.set('file', '');
                $('#photo').attr('src', '');

                $('#display_photo').hide();
                $('#add_photo').show();
            }
        })
    });
})(FMS, Backbone, _, $);
