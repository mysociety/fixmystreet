;(function(FMS, Backbone, _, $) {
    _.extend( FMS, {
        Report: Backbone.Model.extend({
            urlRoot: CONFIG.FMS_URL + 'report/ajax',

            defaults: {
                lat: 0,
                lon: 0,
                title: '',
                details: '',
                may_show_name: '',
                category: '',
                phone: '',
                pc: '',
                file: ''
            },

            sync: function(method, model, options) {
                switch (method) {
                    case 'create':
                        this.post(model,options);
                        break;
                    case 'read':
                        Backbone.ajaxSync(method, model, options);
                        break;
                    default:
                        return true;
                }
            },

            parse: function(res) {
                if ( res.report && res.report.latitude ) {
                    return {
                        lat: res.report.latitude,
                        lon: res.report.longitude,
                        title: res.report.title,
                        details: res.report.detail,
                        photo: res.report.photo && res.report.photo.url ? CONFIG.FMS_URL + res.report.photo.url : null,
                        meta: res.report.meta,
                        confirmed_pp: res.report.confirmed_pp,
                        created_pp: res.report.created_pp,
                        category: res.report.category,
                        state: res.report.state,
                        state_t: res.report.state_t,
                        is_fixed: res.report.is_fixed,
                        used_map: res.report.used_map,
                        update_time: res.updates ? res.updates.update_pp : null,
                        update: res.updates ? res.updates.details : null
                    };
                }
                return false;
            },

            post: function(model,options) {

                console.log(model.toJSON());
                console.log(options);

                var params = {
                    service: device.platform,
                    title: model.get('title'),
                    detail: model.get('details'),
                    category: model.get('category'),
                    lat: model.get('lat'),
                    lon: model.get('lon'),
                    pc: model.get('pc'),
                    may_show_name: $('#form_may_show_name').val() || 0,
                    used_map: 1
                };

                if ( FMS.currentUser ) {
                    params.name = FMS.currentUser.get('name');
                    params.email = FMS.currentUser.get('email');
                    params.phone = FMS.currentUser.get('phone');
                    params.password_sign_in = FMS.currentUser.get('password');
                    params.submit_sign_in = 1;
                } else {
                    params.name = $('#form_name').val();
                    params.email = $('#form_email').val();
                    params.phone = $('#form_phone').val();
                    params.password_sign_in = $('#password_sign_in').val();

                    if ( this.submit_clicked == 'submit_sign_in' ) {
                        params.submit_sign_in = 1;
                    } else {
                        params.submit_register = 1;
                    }

                    /*
                    FMS.currentUser = new FMS.User( {
                        name: params.name,
                        email: params.email,
                        phone: params.phone,
                        password: params.password
                    });
                   */
                }

                var that = this;
                if ( model.get('file') && model.get('file') !== '' ) {
                    var handlers = options;
                    var fileUploadSuccess = function(r) {
                        $('#ajaxOverlay').hide();
                        if ( r.response ) {
                            var data;
                            try {
                                data = JSON.parse( decodeURIComponent(r.response) );
                            }
                            catch(err) {
                                data = {};
                            }
                            that.trigger('sync', that, data, options);
                        } else {
                            that.trigger('error', that, FMS.strings.report_send_error, options);
                        }
                    };

                    var fileUploadFail = function() {
                        $('#ajaxOverlay').hide();
                        that.trigger('error', that, STRINGS.report_send_error, options);
                    };

                    fileURI = model.get('file');

                    var options = new FileUploadOptions();
                    options.fileKey="photo";
                    options.fileName=fileURI.substr(fileURI.lastIndexOf('/')+1);
                    options.mimeType="image/jpeg";
                    options.params = params;
                    options.chunkedMode = false;

                    $('#ajaxOverlay').show();
                    var ft = new FileTransfer();
                    ft.upload(fileURI, CONFIG.FMS_URL + "report/new/mobile", fileUploadSuccess, fileUploadFail, options);
                } else {
                    $.ajax( {
                        url: CONFIG.FMS_URL + "report/new/mobile",
                        type: 'POST',
                        data: params,
                        dataType: 'json',
                        timeout: 30000,
                        success: function(data) {
                            if ( data.success ) {
                                that.trigger('sync', that, data, options);
                            } else {
                                that.trigger('error', that, data, options);
                            }
                        },
                        error: function (data, status, errorThrown ) {
                            console.log(FMS.strings.report_send_error);
                            options.error( data );
                        }
                    } );
                }
            },

            getLastUpdate: function(time) {
                if ( time ) {
                    props.time = time;
                }

                if ( !props.time ) {
                    return '';
                }

                var t;
                if ( typeof props.time === 'String' ) {
                    t = new Date( parseInt(props.time, 10) );
                } else {
                    t = props.time;
                }
            }
        })
    });
})(FMS, Backbone, _, $);
