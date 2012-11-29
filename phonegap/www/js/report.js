function Report(spec) {
    var my_id = -1;
    var props = spec || {
        lat: 0,
        lon: 0,
        title: '',
        details: '',
        may_show_name: '',
        category: '',
        phone: '',
        pc: ''
    };

    return {
        id: function() { return my_id; },
        lat: function(lat) { if ( typeof lat !== 'undefined' ) { props.lat = lat; } return props.lat; },
        lon: function(lon) { if ( typeof lon !== 'undefined' ) { props.lon = lon; } return props.lon; },
        title: function(title) { if ( typeof title !== 'undefined' ) { props.title = title; } return props.title; },
        detail: function(detail) { if ( typeof detail !== 'undefined' ) { props.detail = detail; } return props.detail; },
        category: function(category) { if ( typeof category !== 'undefined' ) { props.category = category; } return props.category; },
        phone: function(phone) { if ( typeof phone !== 'undefined' ) { props.phone = phone; } return props.phone; },
        pc: function(pc) { if ( typeof pc !== 'undefined' ) { props.pc = pc; } return props.pc; },
        may_show_name: function(may_show_name) { if ( typeof may_show_name !== 'undefined' ) { props.may_show_name = may_show_name; } return props.may_show_name; },
        file: function(file) { if ( typeof file !== 'undefined' ) { props.file = file; } return props.file; },
        name: function(name) { if ( typeof name !== 'undefined' ) { props.name = name; } return props.name; },
        email: function(email) { if ( typeof email !== 'undefined' ) { props.email = email; } return props.email; },
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
        },
        load: function(load_id) {
            var reports = localStorage.getObject('reports');
            props = reports[load_id];
            my_id = load_id;
        },
        save: function() {
            var reports = localStorage.getObject('reports');
            if ( ! reports ) {
                reports = [];
            }
            props.time = new Date().getTime();
            if ( my_id != -1 ) {
                reports[my_id] = props;
            } else {
                reports.push( props );
                my_id = reports.length - 1;
            }
            localStorage.setObject('reports', reports);
        },
        update: function(spec) {
            props = spec;
        },
        remove: function(del_id) {
            if ( del_id ) {
                this.load(del_id);
            }
            var reports = localStorage.getObject('reports');
            delete reports[my_id];
            localStorage.setObject('reports', reports);
        },
        reset: function() {

        }
    };
}
