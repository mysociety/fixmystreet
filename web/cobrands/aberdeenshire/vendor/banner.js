console.log('banner.js');

var cookie_control_config = {
 apiKey: '76b723a38e6a5f44dc71823e6c18a0aef4292135',
 product: 'PRO_MULTISITE',
 initialState: 'OPEN',
 text: {
  title: 'This website uses cookies',
  intro: 'Some of these cookies are essential, while others help us to improve your experience by providing insights into how the site is being used.',
  necessaryTitle: 'Necessary cookies',
  necessaryDescription: 'Necessary cookies enable core functionality. The website cannot function properly without these cookies, and can only be disabled by changing your browser preferences.',
  acceptRecommended: 'Accept recommended settings'
 },
 statement: {
  description: 'You can find more information on our',
  name: 'cookie page',
  url: '/online/site-information/',
  updated: '28/10/2021'
 },
 necessaryCookies: ['SVT', 'XSRF-TOKEN', 'XSRF-V', '__RequestVerificationToken', 'UMB*', 'civic_*','CookieControl'],
 optionalCookies: [
  {
   name: 'analytics',
   label: 'Google Analytics',
   description: 'We use Google Analytics to collect information about how you use our website. We do this to help make sure the site is meeting the needs of its users and to help us make improvements.',
   cookies: ['_ga','_ga*', '_gid', '_gat', '__utma', '__utmt', '__utmb', '__utmc', '__utmz', '__utmv'],
   recommendedState: false,
   onAccept: function () {
    gtag('consent', 'update', { 'analytics_storage': 'granted' });
   },
   onRevoke: function () {
    gtag('consent', 'update', { 'analytics_storage': 'denied' });
   }
  }
 ],
 position: 'LEFT',
 theme: 'DARK',
 branding: {
  backgroundColor: '#004990',
  toggleText: '#FFF',
  toggleColor: '#2f2f5f',
  toggleBackground: 'black',
  buttonIcon: null,
  buttonIconWidth: '64px',
  buttonIconHeight: '64px',
  removeIcon: false,
  removeAbout: true
 },
 accessibility: {
  highlightFocus: true,
  outline: true
 }
};
setTimeout(
 function () {
  var ccContent = document.getElementById('ccc-content');
  var ccIcon = document.getElementById('ccc-icon');
  if (!!ccContent) {
   var ccClose = document.getElementById('ccc-close');
   if (!!ccIcon)
    ccIcon.click();
   if (!!ccClose)
    ccClose.focus();
  }
  else {
   if (!!ccIcon)
    ccIcon.focus();
  }
 }, 10);
