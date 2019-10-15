describe('Duplicate tests', function() {
    it('does not try and fetch duplicates which will not get shown', function() {
      cy.server();
      cy.route('/report/new/ajax*').as('report-ajax');
      cy.request({
        method: 'POST',
        url: '/auth?r=/',
        form: true,
        body: { username: 'admin@example.org', password_sign_in: 'password' }
      });
      cy.visit('http://fixmystreet.localhost:3001/report/1');
      cy.contains('Report another problem here').click();
      cy.wait('@report-ajax');
      cy.get('[id=category_group]').select('Potholes');
      cy.wait(500);
      cy.get('[name=title').should('be.visible');
    });

    it('hides everything when duplicate suggestions are shown', function() {
      cy.server();
      cy.route('/report/new/ajax*').as('report-ajax');
      cy.visit('http://borsetshire.localhost:3001/_test/setup/regression-duplicate-hide'); // Server-side setup
      cy.visit('http://borsetshire.localhost:3001/report/1');
      cy.contains('Report another problem here').click();
      cy.wait('@report-ajax');
      cy.get('[id=category_group]').select('Licensing');
      cy.get('[id=subcategory_Licensing]').select('Skips');
      cy.get('.extra-category-questions').should('not.be.visible');
      cy.visit('http://borsetshire.localhost:3001/_test/teardown/regression-duplicate-hide');
    });

    it('does not show duplicate suggestions when signing in during reporting', function() {
      cy.server();
      cy.route('/report/new/ajax*').as('report-ajax');
      cy.route('/around/nearby*').as('nearby-ajax');
      cy.visit('http://borsetshire.localhost:3001/report/1');
      cy.contains('Report another problem here').click();
      cy.wait('@report-ajax');
      cy.get('[id=category_group]').select('Potholes');
      cy.wait('@nearby-ajax');
      cy.get('.js-hide-duplicate-suggestions:first').should('be.visible').click();
      cy.get('[name=title]').type('Title');
      cy.get('[name=detail]').type('Detail');
      cy.get('.js-new-report-user-show').click();
      cy.get('.js-new-report-show-sign-in').should('be.visible').click();
      cy.get('#form_username_sign_in').type('user@example.org');
      cy.get('[name=password_sign_in]').type('password');
      cy.get('[name=password_sign_in]').parents('form').submit();
      cy.get('#map_sidebar').should('contain', 'check and confirm your details');
      cy.get('#js-duplicate-reports').should('not.exist');
    });

    it('lets an inspector see duplicate reports coming from /reports', function() {
      cy.request({
        method: 'POST',
        url: 'http://borsetshire.localhost:3001/auth?r=/reports',
        form: true,
        body: { username: 'admin@example.org', password_sign_in: 'password' }
      });
      cy.visit('http://borsetshire.localhost:3001/reports');
      cy.get('[href$="/report/1"]:last').click();
      cy.get('#report_inspect_form #state').select('Duplicate');
      cy.get('#js-duplicate-reports li h3 a').should('have.attr', 'href', '/report/1');
    });

    it('lets an inspector see duplicate reports coming from /around', function() {
      cy.request({
        method: 'POST',
        url: 'http://borsetshire.localhost:3001/auth?r=/reports',
        form: true,
        body: { username: 'admin@example.org', password_sign_in: 'password' }
      });
      cy.visit('http://borsetshire.localhost:3001/report/1');
      cy.contains('Back to all').click();
      cy.get('[href$="/report/1"]:last').click();
      cy.get('#report_inspect_form #state').select('Duplicate');
      cy.get('#js-duplicate-reports li h3 a').should('have.attr', 'href', '/report/1');
    });

});
