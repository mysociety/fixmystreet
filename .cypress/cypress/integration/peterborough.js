describe('new report form', function() {

  beforeEach(function() {
    cy.server();
    cy.route('/report/new/ajax*').as('report-ajax');
    cy.route("**/peterborough.assets/4/*", 'fixture:peterborough_pcc.json').as('pcc');
    cy.route("**/peterborough.assets/3/*", 'fixture:peterborough_non_pcc.json').as('non_pcc');
    cy.visit('http://peterborough.localhost:3001/');
    cy.contains('Peterborough');
    cy.get('[name=pc]').type('PE1 1HF');
    cy.get('[name=pc]').parents('form').submit();
    cy.get('#map_box').click();
    cy.wait('@report-ajax');
  });

  it('is hidden when emergency option is yes', function() {
    cy.pickCategory('Fallen branch');
    cy.nextPageReporting();
    cy.get('#form_emergency').select('yes');
    cy.get('.js-post-category-messages:visible').should('contain', 'Please phone customer services to report this problem.');
    cy.get('.js-reporting-page--next:visible').should('be.disabled');
    cy.get('#form_emergency').select('no');
    cy.get('.js-post-category-messages:visible').should('not.contain', 'Please phone customer services to report this problem.');
    cy.get('.js-reporting-page--next:visible').should('not.be.disabled');
  });

  it('is hidden when private land option is yes', function() {
    cy.pickCategory('Fallen branch');
    cy.nextPageReporting();
    cy.get('#form_private_land').select('yes');
    cy.get('.js-post-category-messages:visible').should('contain', 'The council do not have powers to address issues on private land.');
    cy.get('.js-reporting-page--next:visible').should('be.disabled');
    cy.get('#form_private_land').select('no');
    cy.get('.js-post-category-messages:visible').should('not.contain', 'The council do not have powers to address issues on private land.');
    cy.get('.js-reporting-page--next:visible').should('not.be.disabled');
  });

  it('flytipping/graffiti categories handle land types correctly', function() {
    cy.pickCategory('General fly tipping');
    cy.nextPageReporting();
    cy.get('#js-environment-message:visible');
    cy.get('#form_hazardous').select('yes');
    cy.get('.js-post-category-messages:visible').should('contain', 'Please phone customer services to report this problem');
    cy.get('#map_sidebar').scrollTo('bottom');
    cy.get('.js-reporting-page--next:visible').should('be.disabled');
    cy.get('#form_hazardous').select('no');
    cy.get('.js-post-category-messages:visible').should('not.contain', 'Please phone customer services to report this problem');
    cy.get('.js-reporting-page--next:visible').should('not.be.disabled');
    cy.visit('http://peterborough.localhost:3001/report/new?longitude=-0.242007&latitude=52.571903');
    cy.wait('@report-ajax');
    cy.pickCategory('General fly tipping');
    cy.get('#js-environment-message:hidden');
    cy.visit('http://peterborough.localhost:3001/report/new?longitude=-0.242007&latitude=52.571903');
    cy.wait('@report-ajax');
    cy.pickCategory('Non offensive graffiti');
    cy.get('#js-graffiti-message:hidden');
    cy.visit('http://peterborough.localhost:3001/report/new?longitude=-0.241841&latitude=52.570792');
    cy.wait('@report-ajax');
    cy.pickCategory('General fly tipping');
    cy.get('#map_sidebar').scrollTo('top');
    cy.get('#js-environment-message:visible');
    cy.visit('http://peterborough.localhost:3001/report/new?longitude=-0.241841&latitude=52.570792');
    cy.wait('@report-ajax');
    cy.pickCategory('Non offensive graffiti');
    cy.get('#map_sidebar').scrollTo('top');
    cy.get('#js-graffiti-message:visible');
  });

  it('correctly changes the asset select message', function() {
    cy.pickCategory('Street lighting');
    cy.get('.category_meta_message').should('contain', 'You can pick a light from the map');
    cy.pickCategory('Trees');
    cy.get('.category_meta_message').should('contain', 'You can pick a tree from the map');
  });
});

describe('Roadworks', function() {
  beforeEach(function() {
    cy.server();
    cy.route('/report/new/ajax*').as('report-ajax');
    cy.route("**/peterborough.assets/4/*", 'fixture:peterborough_pcc.json').as('pcc');
    cy.route("**/peterborough.assets/3/*", 'fixture:peterborough_non_pcc.json').as('non_pcc');
    cy.route('/streetmanager.php**', 'fixture:peterborough_roadworks.json').as('roadworks');
    cy.visit('http://peterborough.localhost:3001/');
    cy.contains('Peterborough');
    cy.get('[name=pc]').type('PE1 1HF');
    cy.get('[name=pc]').parents('form').submit();
    cy.get('#map_box').click();
    cy.wait('@report-ajax');
  });

  it('displays nearby roadworks', function() {
    cy.wait('@roadworks');
    cy.pickCategory('Pothole');
    cy.nextPageReporting();
    cy.contains('Roadworks are scheduled near this location').should('be.visible');
    cy.contains('Parapet improvement').should('be.visible');
    cy.go('back');
    cy.pickCategory('Fallen branch');
    cy.nextPageReporting();
    cy.should('not.contain', 'Roadworks are scheduled near this location');
  });
});

describe('National site tests', function() {
  it('flytipping/graffiti categories handle land types correctly on .com', function() {
    cy.server();
    cy.route('/report/new/ajax*').as('report-ajax');
    cy.route("**/peterborough.assets/4/*", 'fixture:peterborough_pcc.json').as('pcc');
    cy.route("**/peterborough.assets/3/*", 'fixture:peterborough_non_pcc.json').as('non_pcc');
    cy.visit('http://fixmystreet.localhost:3001/');
    cy.get('[name=pc]').type('PE1 1HF');
    cy.get('[name=pc]').parents('form').submit();
    cy.get('#map_box').click();
    cy.wait('@report-ajax');
    cy.pickCategory('General fly tipping');
    cy.nextPageReporting();
    cy.get('#js-environment-message:visible');
    cy.get('#form_hazardous').select('yes');
    cy.get('.js-post-category-messages:visible').should('contain', 'Please phone customer services to report this problem');
    cy.get('#map_sidebar').scrollTo('bottom');
    cy.get('.js-reporting-page--next:visible').should('be.disabled');
    cy.get('#form_hazardous').select('no');
    cy.get('.js-post-category-messages:hidden').should('not.contain', 'Please phone customer services to report this problem');
    cy.get('.js-reporting-page--next:visible').should('not.be.disabled');
    cy.visit('http://fixmystreet.localhost:3001/report/new?longitude=-0.242007&latitude=52.571903');
    cy.wait('@report-ajax');
    cy.pickCategory('General fly tipping');
    cy.get('#map_sidebar').scrollTo('top');
    cy.get('#js-environment-message:hidden');
    cy.visit('http://fixmystreet.localhost:3001/report/new?longitude=-0.242007&latitude=52.571903');
    cy.wait('@report-ajax');
    cy.pickCategory('Non offensive graffiti');
    cy.get('#map_sidebar').scrollTo('top');
    cy.get('#js-graffiti-message:hidden');
    cy.visit('http://fixmystreet.localhost:3001/report/new?longitude=-0.241841&latitude=52.570792');
    cy.wait('@report-ajax');
    cy.pickCategory('General fly tipping');
    cy.get('#map_sidebar').scrollTo('top');
    cy.get('#js-environment-message:visible');
    cy.visit('http://fixmystreet.localhost:3001/report/new?longitude=-0.241841&latitude=52.570792');
    cy.wait('@report-ajax');
    cy.pickCategory('Non offensive graffiti');
    cy.get('#map_sidebar').scrollTo('top');
    cy.get('#js-graffiti-message:visible');
  });

});
