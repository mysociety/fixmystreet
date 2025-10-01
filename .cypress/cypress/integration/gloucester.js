describe('Gloucester cobrand', function(){
    describe('Reporting restrictions making reports on not on plot', function() {

        it('displays stopper and can not progress trying to report on not owned land', function(){
            cy.server();
            cy.route('/report/new/ajax*').as('report-ajax');
            cy.route('**gloucester.assets*all_plots*', 'fixture:gloucester_plots_joint.json').as('gloucester_plots');
            cy.route('**gloucester.assets*adopted_streets*', 'fixture:gloucester_empty.json').as('gloucester_streets');
            cy.visit('http://gloucester.localhost:3001/report/new?longitude=-2.2458&latitude=51.86506');
            cy.wait('@report-ajax');
            cy.pickCategory('Broken glass');
            cy.wait('@gloucester_plots');
            cy.wait('@gloucester_streets');
            cy.get('.pre-button-messaging').contains("The location you've selected appears to be privately owned");
            cy.get('.js-reporting-page--next:visible').should('be.disabled');
        });

        it('displays customised stopper and can not progress trying to report on GHC plot', function(){
            cy.server();
            cy.route('/report/new/ajax*').as('report-ajax');
            cy.route('**gloucester.assets*all_plots*', 'fixture:gloucester_plots_GCH.json').as('gloucester_plots');
            cy.route('**gloucester.assets*adopted_streets*', 'fixture:gloucester_empty.json').as('gloucester_streets');
            cy.visit('http://gloucester.localhost:3001/report/new?longitude=-2.243133&latitude=51.865329');
            cy.pickCategory('Broken glass');
            cy.wait('@report-ajax');
            cy.wait('@gloucester_plots');
            cy.wait('@gloucester_streets');
            cy.get('.pre-button-messaging').contains("The location you've selected appears to be privately owned").should('not.exist');
            cy.get('.pre-button-messaging').contains("This land is not owned or managed by");
            cy.get('.js-reporting-page--next:visible').should('be.disabled');
        });

        it('does not display stopper message and allows reporting when selecting a jointly owned plot', function(){
            cy.server();
            cy.route('/report/new/ajax*').as('report-ajax');
            cy.route('**gloucester.assets*all_plots*', 'fixture:gloucester_plots_joint.json').as('gloucester_plots');
            cy.route('**gloucester.assets*adopted_streets*', 'fixture:gloucester_empty.json').as('gloucester_streets');
            cy.visit('http://gloucester.localhost:3001/report/new?longitude=-2.243133&latitude=51.865329');
            cy.pickCategory('Broken glass');
            cy.wait('@report-ajax');
            cy.wait('@gloucester_plots');
            cy.wait('@gloucester_streets');
            cy.get('.pre-button-messaging').contains("The location you've selected appears to be privately owned").should('not.exist');
            cy.get('.pre-button-messaging').contains("This land is not owned or managed by").should('not.exist');
            cy.get('.js-reporting-page--next:visible').should('not.be.disabled');
            cy.nextPageReporting();
            cy.nextPageReporting();
            cy.contains('These will be sent to Gloucester City Council and also published').should('be.visible');
        });

        it('does not display stopper message and allows reporting when selecting a street', function(){
            cy.server();
            cy.route('/report/new/ajax*').as('report-ajax');
            cy.route('**gloucester.assets*all_plots*', 'fixture:gloucester_empty.json').as('gloucester_plots');
            cy.route('**gloucester.assets*adopted_streets*', 'fixture:gloucester_streets.json').as('gloucester_streets');
            cy.visit('http://gloucester.localhost:3001/report/new?longitude=-2.243133&latitude=51.865329');
            cy.pickCategory('Broken glass');
            cy.wait('@report-ajax');
            cy.wait('@gloucester_plots');
            cy.wait('@gloucester_streets');
            cy.get('.pre-button-messaging').contains("The location you've selected appears to be privately owned").should('not.exist');
            cy.get('.pre-button-messaging').contains("This land is not owned or managed by").should('not.exist');
            cy.get('.js-reporting-page--next:visible').should('not.be.disabled');
            cy.nextPageReporting();
            cy.nextPageReporting();
            cy.contains('These will be sent to Gloucester City Council and also published').should('be.visible');
        });

        it('does update message when clicking on different features', function(){
            cy.server();
            cy.route('/report/new/ajax*').as('report-ajax');
            cy.route('**gloucester.assets*all_plots*', 'fixture:gloucester_plots_GCH.json').as('gloucester_plots');
            cy.route('**gloucester.assets*adopted_streets*', 'fixture:gloucester_empty.json').as('gloucester_streets');

            cy.visit('http://gloucester.localhost:3001/report/new?longitude=-2.2458&latitude=51.86506');
            cy.wait('@report-ajax');
            cy.wait('@gloucester_plots');
            cy.wait('@gloucester_streets');
            cy.get('.pre-button-messaging').contains("The location you've selected appears to be privately owned");
            cy.get('.pre-button-messaging').contains("This land is not owned or managed by").should('not.exist');

            cy.visit('http://gloucester.localhost:3001/report/new?longitude=-2.243133&latitude=51.865329');
            cy.wait('@report-ajax');
            cy.wait('@gloucester_plots');
            cy.wait('@gloucester_streets');
            cy.get('.pre-button-messaging').contains("The location you've selected appears to be privately owned").should('not.exist');
            cy.get('.pre-button-messaging').contains("This land is not owned or managed by");

            cy.visit('http://gloucester.localhost:3001/report/new?longitude=-2.2458&latitude=51.86506');
            cy.wait('@report-ajax');
            cy.wait('@gloucester_plots');
            cy.wait('@gloucester_streets');
            cy.get('.pre-button-messaging').contains("The location you've selected appears to be privately owned");
            cy.get('.pre-button-messaging').contains("This land is not owned or managed by").should('not.exist');

            cy.route('**gloucester.assets*all_plots*', 'fixture:gloucester_empty.json').as('gloucester_plots');
            cy.route('**gloucester.assets*adopted_streets*', 'fixture:gloucester_streets.json').as('gloucester_streets');
            cy.visit('http://gloucester.localhost:3001/report/new?longitude=-2.243133&latitude=51.865329');
            cy.wait('@report-ajax');
            cy.wait('@gloucester_plots');
            cy.wait('@gloucester_streets');
            cy.get('.pre-button-messaging').contains("The location you've selected appears to be privately owned").should('not.exist');
            cy.get('.pre-button-messaging').contains("This land is not owned or managed by").should('not.exist');
            cy.get('.js-reporting-page--next:visible').should('not.be.disabled');
            cy.nextPageReporting();
            cy.nextPageReporting();
            cy.contains('These will be sent to Gloucester City Council and also published').should('be.visible');
        });
    });
});
