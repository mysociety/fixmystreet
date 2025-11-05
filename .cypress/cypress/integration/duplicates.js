describe('Duplicate tests', function() {
    it('has a separate duplicate suggestions step when on cobrands on FMS', function() {
      cy.server();
      cy.route('/report/new/ajax*').as('report-ajax');
      cy.route('/around/nearby*').as('nearby-ajax');
      cy.visit('http://fixmystreet.localhost:3001/_test/setup/regression-duplicate-hide'); // Server-side setup
      cy.visit('http://fixmystreet.localhost:3001/report/1');
      cy.contains('Report another problem here').click();
      cy.wait('@report-ajax');
      cy.pickCategory('Licensing');
      cy.nextPageReporting();
      cy.pickSubcategory('Licensing', 'Skips');
      cy.wait('@nearby-ajax');
      cy.nextPageReporting();
      cy.contains('Already been reported?').should('be.visible');
      cy.get('.extra-category-questions').should('not.be.visible');
      cy.visit('http://fixmystreet.localhost:3001/_test/teardown/regression-duplicate-hide');
    });

    it('has a separate duplicate suggestions step when needed', function() {
      cy.server();
      cy.route('/report/new/ajax*').as('report-ajax');
      cy.route('/around/nearby*').as('nearby-ajax');
      cy.visit('http://borsetshire.localhost:3001/_test/setup/regression-duplicate-hide'); // Server-side setup
      cy.visit('http://borsetshire.localhost:3001/report/1');
      cy.contains('Report another problem here').click();
      cy.wait('@report-ajax');
      cy.pickCategory('Licensing');
      cy.nextPageReporting();
      cy.pickSubcategory('Licensing', 'Skips');
      cy.wait('@nearby-ajax');
      cy.nextPageReporting();
      cy.contains('Already been reported?').should('be.visible');
      cy.get('.extra-category-questions').should('not.be.visible');
      cy.visit('http://borsetshire.localhost:3001/_test/teardown/regression-duplicate-hide');
    });

    it('still maintains asset problem when duplicates shown on mobile', function() {
      cy.viewport(480, 800);
      cy.server();
      cy.route('/report/new/ajax*').as('report-ajax');
      cy.route('/around/nearby*').as('nearby-ajax');
      cy.visit('http://borsetshire.localhost:3001/_test/setup/regression-duplicate-mobile');
      cy.visit('http://borsetshire.localhost:3001/report/1');
      cy.contains('Report another problem here').click({ force: true });
      cy.wait('@report-ajax');
      cy.get('#mob_ok').should('be.visible').click();
      cy.pickCategory('Public toilets');
      cy.wait('@nearby-ajax');
      cy.nextPageReporting();
      cy.contains('Already been reported?').should('be.visible');
      cy.nextPageReporting();
      cy.contains('Please select an item').should('be.visible');
      cy.get('.extra-category-questions').should('not.be.visible');
      cy.visit('http://borsetshire.localhost:3001/_test/teardown/regression-duplicate-mobile');
    });

    it('does not show duplicate suggestions when signing in during reporting', function() {
      cy.server();
      cy.route('/report/new/ajax*').as('report-ajax');
      cy.route('/around/nearby*').as('nearby-ajax');
      cy.visit('http://borsetshire.localhost:3001/report/1');
      cy.contains('Report another problem here').click();
      cy.wait('@report-ajax');
      cy.pickCategory('Potholes');
      cy.wait('@nearby-ajax');
      cy.nextPageReporting();
      cy.contains('Already been reported?').should('be.visible');
      cy.nextPageReporting(); // Go past duplicates
      cy.nextPageReporting(); // No photo
      cy.get('[name=title]').type('Title');
      cy.get('[name=detail]').type('Detail');
      cy.nextPageReporting();
      cy.get('.js-new-report-show-sign-in').should('be.visible').click();
      cy.get('#form_username_sign_in').type('user@example.org');
      cy.get('[name=password_sign_in]').type('password');
      cy.get('[name=password_sign_in]').parents('form').submit();
      cy.get('#map_sidebar').should('contain', 'check and confirm your details');
      cy.get('#js-duplicate-reports').should('not.exist');
    });

    it('lets an inspector see duplicate reports coming from /reports', function() {
      cy.visit('http://borsetshire.localhost:3001/auth');
      cy.get('[name=username]').type('admin@example.org');
      cy.contains('Sign in with a password').click();
      cy.get('[name=password_sign_in]').type('password');
      cy.get('[name=sign_in_by_password]').last().click();
      cy.url().should('include', '/my');
      cy.visit('http://borsetshire.localhost:3001/reports');
      cy.get('[href$="/report/1"]').last().click();
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
      cy.get('[href$="/report/1"]').last().click();
      cy.get('#report_inspect_form #state').select('Duplicate');
      cy.get('#js-duplicate-reports li h3 a').should('have.attr', 'href', '/report/1');
    });

    it('does not redisplay duplicates when stopper questions are changed', function() {
      cy.server();
      cy.route('/report/new/ajax*').as('report-ajax');
      cy.route('/around/nearby*').as('nearby-ajax');
      cy.visit('http://borsetshire.localhost:3001/_test/setup/regression-duplicate-stopper'); // Server-side setup
      cy.visit('http://borsetshire.localhost:3001/report/1');
      cy.contains('Report another problem here').click();
      cy.wait('@report-ajax');
      cy.pickCategory('Flytipping');
      cy.wait('@nearby-ajax');
      cy.nextPageReporting();
      cy.get('.extra-category-questions').should('not.be.visible');
      cy.nextPageReporting(); // Go past duplicates
      cy.get('.extra-category-questions').should('be.visible');
      cy.get('[id=form_hazardous]').select('No');
      cy.get('.extra-category-questions').should('be.visible');
      cy.nextPageReporting();
      cy.visit('http://borsetshire.localhost:3001/_test/teardown/regression-duplicate-stopper'); // Server-side setup
    });

});
