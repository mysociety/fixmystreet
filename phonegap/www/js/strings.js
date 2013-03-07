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
            location_error: 'Location error',
            location_problem: 'There was a problem looking up your location',
            multiple_locations: 'More than one location matched that name',
            sync_error: 'Sync error',
            report_send_error: 'There was a problem submitting your report. Please try again',
            missing_location: 'Please enter a location',
            location_check_failed: 'Could not check your location',
            geolocation_failed: 'Could not determine your location',
            select_category: '-- Pick a categoy --',
            required: 'required',
            invalid_email: 'Invalid email',
            photo_failed: 'There was a problem taking your photo',
            no_connection: 'No network connection available for submitting your report. Please try again later',
            more_details: 'More details'
        }
    });
})(FMS, _);
