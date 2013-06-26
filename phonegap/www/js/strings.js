(function (FMS, _) {
    _.extend( FMS, {
        validationStrings: {
            update: 'Please enter a message',
            title: 'Please enter a subject',
            detail: 'Please enter some details',
            name: {
                required: 'Please enter your name',
                validName: 'Please enter your full name, councils need this information - if you do not wish your name to be shown on the site, untick the box below'
            },
            category: 'Please choose a category',
            rznvy: {
                required: 'Please enter your email',
                email: 'Please enter a valid email'
            },
            email: {
                required: 'Please enter your email',
                email: 'Please enter a valid email'
            },
            password: 'Please enter a password'
        },
        strings: {
            login_error: 'There was a problem logging you in. Please try later',
            logout_error: 'There was a problem logging you out. Please try later',
            login_details_error: 'There was a problem logging you in. Please check your email and password',
            password_problem: 'There was a problem with your email/password combination. If you have forgotten your password you can set a new one by returning to the email screen and selecting the set password option',
            location_error: 'Location error',
            location_problem: 'There was a problem looking up your location',
            multiple_locations: 'More than one location matched that name. Select one below or try entering street name and area, or a postcode.',
            sync_error: 'Sync error',
            report_send_error: 'There was a problem submitting your report. Please try again',
            missing_location: 'Please enter a location',
            location_check_failed: 'Could not check your location',
            geolocation_failed: 'Could not determine your location, please search for a street name and area, or postcode instead.',
            geolocation_denied: 'Could not access location services. Please check permissions.',
            select_category: '-- Pick a categoy --',
            required: 'required',
            invalid_email: 'Invalid email',
            invalid_report: 'Invalid report',
            photo_failed: 'There was a problem taking your photo',
            no_connection: 'No network connection available for submitting your report. Please try again later',
            more_details: 'More details'
        }
    });
})(FMS, _);
