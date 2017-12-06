fixmystreet.utils = fixmystreet.utils || {};

fixmystreet.utils.defect_type_format = function(data) {
    return data.extra.defect_code + ' - ' + data.extra.activity_code + ' (' + data.name + ')';
};
