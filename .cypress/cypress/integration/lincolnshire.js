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
            cy.get(
                '#category_meta_message_Damagedmissingcatseye'
            ).should('have.text', '');
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
