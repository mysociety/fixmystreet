;(function (FMS, _) {
    _.extend( FMS, {
        validationStrings: {
            update: 'Please enter a message',
            title: 'Please enter a subject',
            detail: 'Please enter some details',
            name: {
                required: 'Please enter your name',
                validName: 'Please enter your full name, councils need this information – if you do not wish your name to be shown on the site, untick the box below'
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
        }
    })
})(FMS, _);
