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
    cy.get('.pre-button-messaging:visible').should('contain', 'Please phone customer services to report this problem.');
    cy.get('.js-reporting-page--next:visible').should('be.disabled');
    cy.get('#form_emergency').select('no');
    cy.get('.pre-button-messaging:visible').should('not.contain', 'Please phone customer services to report this problem.');
    cy.get('.js-reporting-page--next:visible').should('not.be.disabled');
  });

  it('is hidden when private land option is yes', function() {
    cy.pickCategory('Fallen branch');
    cy.nextPageReporting();
    cy.get('#form_private_land').select('yes');
    cy.get('.pre-button-messaging:visible').should('contain', 'The council do not have powers to address issues on private land.');
    cy.get('.js-reporting-page--next:visible').should('be.disabled');
    cy.get('#form_private_land').select('no');
    cy.get('.pre-button-messaging:visible').should('not.contain', 'The council do not have powers to address issues on private land.');
    cy.get('.js-reporting-page--next:visible').should('not.be.disabled');
  });

  it('flytipping/graffiti categories handle land types correctly', function() {
    cy.pickCategory('General fly tipping');
    cy.get('.pre-button-messaging:visible').should('contain', 'You can report cases of fly-tipping on private land');
    cy.nextPageReporting();
    cy.get('#form_hazardous').select('yes');
    cy.get('.pre-button-messaging:visible').should('contain', 'Please phone customer services to report this problem');
    cy.get('.js-reporting-page--next:visible').should('be.disabled');
    cy.get('#form_hazardous').select('no');
    cy.get('.pre-button-messaging:visible').should('not.contain', 'Please phone customer services to report this problem');
    cy.get('.js-reporting-page--next:visible').should('not.be.disabled');
    cy.visit('http://peterborough.localhost:3001/report/new?longitude=-0.242007&latitude=52.571903');
    cy.wait('@report-ajax');
    cy.pickCategory('General fly tipping');
    cy.get('.pre-button-messaging:visible').should('not.exist');
    cy.visit('http://peterborough.localhost:3001/report/new?longitude=-0.242007&latitude=52.571903');
    cy.wait('@report-ajax');
    cy.pickCategory('Non offensive graffiti');
    cy.get('.pre-button-messaging:visible').should('not.exist');
    cy.visit('http://peterborough.localhost:3001/report/new?longitude=-0.241841&latitude=52.570792');
    cy.wait('@report-ajax');
    cy.pickCategory('General fly tipping');
    cy.get('.pre-button-messaging:visible').should('contain', 'You can report cases of fly-tipping on private land');
    cy.visit('http://peterborough.localhost:3001/report/new?longitude=-0.241841&latitude=52.570792');
    cy.wait('@report-ajax');
    cy.pickCategory('Non offensive graffiti');
    cy.get('.pre-button-messaging:visible').should('contain', 'For graffiti on private land this would be deemed');
  });

  it('correctly changes the asset select message', function() {
    cy.pickCategory('Street lighting');
    cy.get('.pre-button-messaging').should('contain', 'Please select a light from the map');
    cy.pickCategory('Trees');
    cy.get('.pre-button-messaging').should('contain', 'Please select a tree from the map');
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
  it.only('flytipping/graffiti categories handle land types correctly on .com', function() {
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
    cy.get('.pre-button-messaging:visible').should('contain', 'You can report cases of fly-tipping on private land');
    cy.nextPageReporting();
    cy.get('#form_hazardous').select('yes');
    cy.get('.pre-button-messaging:visible').should('contain', 'Please phone customer services to report this problem');
    cy.get('.js-reporting-page--next:visible').should('be.disabled');
    cy.get('#form_hazardous').select('no');
    cy.get('.pre-button-messaging:hidden').should('not.contain', 'Please phone customer services to report this problem');
    cy.get('.js-reporting-page--next:visible').should('not.be.disabled');
    cy.visit('http://fixmystreet.localhost:3001/report/new?longitude=-0.242007&latitude=52.571903');
    cy.wait('@report-ajax');
    cy.pickCategory('General fly tipping');
    cy.get('.pre-button-messaging:visible').should('not.exist');
    cy.visit('http://fixmystreet.localhost:3001/report/new?longitude=-0.242007&latitude=52.571903');
    cy.wait('@report-ajax');
    cy.pickCategory('Non offensive graffiti');
    cy.get('.pre-button-messaging:visible').should('not.exist');
    cy.visit('http://fixmystreet.localhost:3001/report/new?longitude=-0.241841&latitude=52.570792');
    cy.wait('@report-ajax');
    cy.pickCategory('General fly tipping');
    cy.get('.pre-button-messaging:visible').should('contain', 'You can report cases of fly-tipping on private land');
    cy.visit('http://fixmystreet.localhost:3001/report/new?longitude=-0.241841&latitude=52.570792');
    cy.wait('@report-ajax');
    cy.pickCategory('Non offensive graffiti');
    cy.get('.pre-button-messaging:visible').should('contain', 'For graffiti on private land this would be deemed');
  });

});
