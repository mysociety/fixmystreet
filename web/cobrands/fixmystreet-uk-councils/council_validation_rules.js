confirm_validation_rules = {
    name: {
      required: true,
      maxlength: 50
    },
    phone: {
      maxlength: 20
    },
    detail: {
      required: true,
      maxlength: 2000
    }
};

body_validation_rules = {
    'Buckinghamshire County Council': confirm_validation_rules,
    'Lincolnshire County Council': confirm_validation_rules,
    'Bath and North East Somerset Council': confirm_validation_rules,
    'Rutland County Council': {
        name: {
          required: true,
          maxlength: 40
        }
    },
    'Bromley Council': {
        detail: {
          required: true,
          maxlength: 1750
        }
    },
    'Oxfordshire County Council': {
        detail: {
          required: true,
          maxlength: 1700
        },
        name: {
          required: true,
          maxlength: 50
        },
        phone: {
          maxlength: 20
        },
        email: {
          maxlength: 50
        }
    },
    'Northamptonshire County Council': {
        title: {
          required: true,
          maxlength: 120
        }
    }
};
