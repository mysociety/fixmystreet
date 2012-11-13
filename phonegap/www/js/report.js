function Report(spec) {
    var id = -1;
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
        id: function() { return id; },
        lat: function(lat) { if ( lat ) { props.lat = lat; } return props.lat; },
        lon: function(lon) { if ( lon ) { props.lon = lon; } return props.lon; },
        title: function(title) { if ( title ) { props.title = title; } return props.title; },
        detail: function(detail) { if ( detail ) { props.detail = detail; } return props.detail; },
        phone: function(phone) { if ( phone ) { props.phone = phone; } return props.phone; },
        pc: function(pc) { if ( pc ) { props.pc = pc; } return props.pc; },
        may_show_name: function(may_show_name) { if ( may_show_name ) { props.may_show_name = may_show_name; } return props.may_show_name; },
        file: function(file) { if ( file ) { props.file = file; } return props.file; },
        getLastUpdate: function(time) {
            if ( time ) {
                props.time = time;
            }

            if ( !props.time ) {
                return '';
            }

            var t;
            if ( typeof props.time === 'String' ) {
                t = new Date( props.time );
            } else {
                t = props.time;
            }
        },
        load: function(id) {
            var reports = localStorage.getObject('reports');
            props = reports[id];
            id = id;
        },
        save: function() {
            var reports = localStorage.getObject('reports');
            if ( ! reports ) {
                reports = [];
            }
            props.time = new Date();
            if ( id != -1 ) {
                reports[id] = props;
            } else {
                reports.push( props );
                id = reports.length - 1;
            }
            localStorage.setObject('reports', reports);
        },
        remove: function(del_id) {
            if ( del_id ) {
                this.load(del_id);
            }
            var reports = localStorage.getObject('reports');
            delete report[id];
            localStorage.setObject('reports', reports);
        },
        reset: function() {

        }
    };
}
