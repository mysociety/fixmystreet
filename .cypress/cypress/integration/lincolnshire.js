describe('Lincolnshire cobrand', function(){
    describe('making a report as a new user', function() {
        before(function(){
            cy.server();
            cy.route('/report/new/ajax*').as('report-ajax');

            cy.visit('http://lincolnshire.localhost:3001/report/new?longitude=-0.502566&latitude=52.656144');
            cy.contains('Lincolnshire County Council');

            cy.wait('@report-ajax');
        });

        it('does not display extra message when selecting a "road" category', function(){
            cy.pickCategory('Damaged/missing cats eye');
            cy.get('.pre-button-messaging').should('not.be.visible');
        });

        it('clicks through to photo section', function(){
            cy.nextPageReporting();
            cy.contains('Drag photos here').should('be.visible');
        });

        it('clicks through to public details page', function(){
            cy.nextPageReporting();
            cy.contains('Public details').should('be.visible');
        });

        it('cannot click through to next page without details', function(){
            cy.nextPageReporting();
            cy.get('#form_title-error').should('be.visible');
        });

        it('submits public details form with sufficient details', function(){
            cy.get('#form_title').type('Missing cat\'s eye');
            cy.get('#form_detail').type('This cat must be a pirate');
            cy.nextPageReporting();
            cy.get('#form_name').should('be.visible');
        });

        it('submits personal details form with sufficient details', function(){
            cy.get('#form_name').type('Kitty Wake');
            cy.get('#form_username_register').type('a@b.com');
            cy.get('#mapForm').submit();
            cy.contains('Nearly done! Now check your email…').should('be.visible');
        });
    });
});

describe('Grass cutting layer', function(){

    beforeEach(function() {
        cy.server();
        cy.route('/report/new/ajax*').as('report-ajax');
    });

    it('proceeds with report to LCC if LCC and no date given', function(){
        cy.route('POST', '**/mapserver/lincs', 'fixture:lincs_grass_lcc_noDate.xml').as('grass');
        cy.visit('http://lincolnshire.localhost:3001/report/new?longitude=-0.510956&latitude=52.655591');
        cy.wait('@report-ajax');
        cy.pickCategory('Grass cutting');
        cy.wait('@grass');
        cy.nextPageReporting();
        cy.contains('Drag photos here').should('be.visible');
        cy.nextPageReporting();
        cy.contains('These will be sent to Lincolnshire County Council').should('be.visible');
    });

    it('presents a message with grass cutting date if LCC responsibility and cut date given, and reports to LCC if continued', function(){
        cy.route('POST', '**/mapserver/lincs', 'fixture:lincs_grass_lcc_withDates.xml').as('grass');
        cy.clock(Date.UTC(2020, 6, 10), ['Date']);
        cy.visit('http://lincolnshire.localhost:3001/report/new?longitude=-0.510956&latitude=52.655591');
        cy.wait('@report-ajax');
        cy.pickCategory('Grass cutting');
        cy.wait('@grass');
        cy.nextPageReporting();
        cy.contains('12 June - 16 July').should('be.visible');
        cy.contains('Thank you for making an enquiry').should('not.be.visible');
        cy.get('.js-reporting-page--active').contains('No');
        cy.get('#lincs-yes-verge-query').contains('Yes').click();
        cy.get('.js-reporting-page--active .js-reporting-page--next').should('be.disabled');
        cy.contains('In rural areas we cut roads to the first').should('not.be.visible');
        cy.contains('Thank you for making an enquiry').should('be.visible');
        cy.go('back');
        cy.get('.js-reporting-page--next').contains('Continue');
        cy.nextPageReporting();
        cy.nextPageReporting();
        cy.contains('Drag photos here').should('be.visible');
        cy.get('.js-reporting-page--next').contains('Continue');
        cy.nextPageReporting();
        cy.contains('These will be sent to Lincolnshire County Council').should('be.visible');
    });

    it('presents a message with grass cutting date if F1 responsibility and cut date given with extra message', function(){
        cy.route('POST', '**/mapserver/lincs', 'fixture:lincs_grass_f1_withDates.xml').as('grass');
        cy.clock(Date.UTC(2020, 6, 10), ['Date']);
        cy.visit('http://lincolnshire.localhost:3001/report/new?longitude=-0.510956&latitude=52.655591');
        cy.wait('@report-ajax');
        cy.pickCategory('Grass cutting');
        cy.wait('@grass');
        cy.nextPageReporting();
        cy.contains('12 June - 16 July').should('be.visible');
        cy.contains('In rural areas we cut roads to the first').should('be.visible');
        cy.contains('Thank you for making an enquiry').should('not.be.visible');
        cy.get('#lincs-yes-verge-query').contains('Yes').click();
        cy.contains('Thank you for making an enquiry').should('be.visible');
    });

    it('presents a message with grass cutting date if F0 responsibility and cut date given with extra message', function(){
        cy.route('POST', '**/mapserver/lincs', 'fixture:lincs_grass_f0_withDates.xml').as('grass');
        cy.clock(Date.UTC(2020, 6, 10), ['Date']);
        cy.visit('http://lincolnshire.localhost:3001/report/new?longitude=-0.510956&latitude=52.655591');
        cy.wait('@report-ajax');
        cy.pickCategory('Grass cutting');
        cy.wait('@grass');
        cy.nextPageReporting();
        cy.contains('on 6 September').should('be.visible');
        cy.contains('In rural areas we cut roads to the first').should('be.visible');
        cy.contains('Thank you for making an enquiry').should('not.be.visible');
        cy.get('#lincs-yes-verge-query').contains('Yes').click();
        cy.contains('Thank you for making an enquiry').should('be.visible');
    });

    it('reports to LCC if LCDC responsibility and data says contact LCC', function(){
        cy.route('POST', '**/mapserver/lincs', 'fixture:lincs_grass_LCDC_contactLCC.xml').as('grass');
        cy.visit('http://lincolnshire.localhost:3001/report/new?longitude=-0.510956&latitude=52.655591');
        cy.wait('@report-ajax');
        cy.pickCategory('Grass cutting');
        cy.wait('@grass');
        cy.nextPageReporting();
        cy.contains('Drag photos here').should('be.visible');
        cy.nextPageReporting();
        cy.contains('These will be sent to Lincolnshire County Council').should('be.visible');
    });

    it('reports to LCDC if their responsibility and data doesn\t say report to LCC ', function(){
        cy.route('POST', '**/mapserver/lincs', 'fixture:lincs_grass_LCDC_contactLCDC.xml').as('grass');
        cy.visit('http://lincolnshire.localhost:3001/report/new?longitude=-0.510956&latitude=52.655591');
        cy.wait('@report-ajax');
        cy.pickCategory('Grass cutting');
        cy.wait('@grass');
        cy.nextPageReporting();
        cy.contains('Drag photos here').should('be.visible');
        cy.nextPageReporting();
        cy.contains('These will be sent to Lincoln City Council').should('be.visible');
    });

    it('presents a parish message if Parish responsibility and stops', function(){
        cy.route('POST', '**/mapserver/lincs', 'fixture:lincs_grass_contact_parish.xml').as('grass');
        cy.visit('http://lincolnshire.localhost:3001/report/new?longitude=-0.510956&latitude=52.655591');
        cy.wait('@report-ajax');
        cy.pickCategory('Grass cutting');
        cy.wait('@grass');
        cy.get('#map_sidebar').scrollTo('bottom');
        cy.contains('responsibility of North Somercotes Parish/Town Council').should('be.visible');
        cy.get('.js-reporting-page--next:visible').should('be.disabled');
    });

});
