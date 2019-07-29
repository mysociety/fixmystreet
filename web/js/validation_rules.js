    core_validation_rules = {
        title: { required: true, notEmail: true },
        detail: { required: true },
        update: { required: true },
        password_register: {
          remote: {
            url: '/auth/common_password',
            type: 'post'
          }
        }
    };

    validation_rules = core_validation_rules;
