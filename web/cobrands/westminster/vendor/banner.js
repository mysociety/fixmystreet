const reportItCookieDefault = "westminster-city-council_cookiecontrol-version";
const reportItCookieDefaultContent = "1.0.0";
const reportItCookie = "westminster-city-council_cookiecontrol";
const reportItCookieContent = "2";
const googleTagManagerUrl =
  "https://www.googletagmanager.com/gtag/js?id=G-89XXDEKFEX";
const cookiePolicyButton = document.querySelector("#cookiepolicy");
const cookieAlert = document.querySelector(".cookiealert");
const declineLink = document.querySelector("#declinepolicy");

const loadGoogleAnalyticsScripts = () => {
  var script1 = document.createElement("script");
  script1.async = true;
  script1.src = googleTagManagerUrl;

  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'G-89XXDEKFEX');

  document.body.appendChild(script1);
};

const isScriptAdded = (scriptUrl) => {
  const scripts = document.getElementsByTagName("script");
  const scriptExists = [...scripts].some((script) => script.src === scriptUrl);
  return scriptExists;
};

const removeBanner = () => cookieAlert.classList.remove("show");

const placeGoogleAnalyticsCookie = () => {
  document.cookie = `${reportItCookie}=${reportItCookieContent}`;
  document.cookie = `${reportItCookieDefault}=${reportItCookieDefaultContent}`;
  if (!isScriptAdded(googleTagManagerUrl)) {
    loadGoogleAnalyticsScripts();
  }
  removeBanner();
};

const declineCookie = (event) => {
  event.preventDefault();
  document.cookie = `${reportItCookieDefault}=${reportItCookieDefaultContent}`;
  removeBanner();
};

cookiePolicyButton.addEventListener("click", () =>
  placeGoogleAnalyticsCookie()
);
declineLink.addEventListener("click", (event) => declineCookie(event));

window.addEventListener("load", () => {
  const cookie = document.cookie;
  if (cookie.includes(reportItCookieDefault)) {
    cookieAlert.classList.remove("show");
  } else {
    cookieAlert.classList.add("show");
  }
  if (cookie.includes(reportItCookie) && !isScriptAdded(googleTagManagerUrl)) {
    loadGoogleAnalyticsScripts();
  }
});
