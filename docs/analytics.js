// Firebase Analytics.
//
// This is the only third-party code the site loads. Everything else — fonts
// included — is served from this origin, so if that property matters to you,
// this file is the one to delete.
//
// Worth knowing what it is: Firebase Analytics for web is Google Analytics 4
// underneath. It writes identifiers to the visitor's browser, which in the
// EU and UK means consent has to be collected before this runs, and a privacy
// policy has to say what is collected. See `startAnalytics` for where a
// consent gate goes.

import { initializeApp } from "https://www.gstatic.com/firebasejs/12.16.0/firebase-app.js";
import {
  getAnalytics,
  isSupported,
  logEvent,
} from "https://www.gstatic.com/firebasejs/12.16.0/firebase-analytics.js";

// From the Firebase console: Project settings → Your apps → Web app → SDK
// setup and configuration.
//
// None of this is secret. A web app's Firebase config identifies a project, it
// does not authorise anything, and it has to reach the browser to work at all.
// Analytics does not even use the API key: collection is keyed by
// `measurementId` and goes to google-analytics.com. The key is here because
// the SDK's config shape includes it, and it is restricted to this site's
// referrers in the Google Cloud console — which matters the day something
// beyond Analytics is added to this project, not today.
//
// One consequence worth knowing rather than discovering: a measurement ID is
// public, and GA4 has no allowlist that stops anyone else sending events to
// it. If the numbers ever look wrong, filter by hostname in GA4 rather than
// looking for a setting here.
const firebaseConfig = {
  apiKey: "AIzaSyBqovMpttbEt3GUPbfA4XTqjn3TEpqVVbU",
  authDomain: "prism-inspector.firebaseapp.com",
  projectId: "prism-inspector",
  storageBucket: "prism-inspector.firebasestorage.app",
  messagingSenderId: "874201660509",
  appId: "1:874201660509:web:2c5b5320872ab7dce1e1b4",
  measurementId: "G-RF1Z6T1LYK",
};

/// Records a download the moment it is asked for.
///
/// The href is written asynchronously by the page's own script, from
/// `latest.json` — so the version is read at click time rather than captured
/// when this runs, which would be before the link has a destination.
function trackDownloads(analytics) {
  const buttons = [
    { id: "download", placement: "hero" },
    { id: "download2", placement: "footer" },
  ];

  for (const { id, placement } of buttons) {
    const link = document.getElementById(id);
    if (!link) continue;

    link.addEventListener("click", () => {
      // Before `latest.json` resolves the button says so and goes nowhere.
      // Counting that as a download would inflate the only number here that
      // anyone will act on.
      if (link.getAttribute("aria-disabled") === "true") return;

      const url = link.href;
      logEvent(analytics, "file_download", {
        placement,
        link_url: url,
        file_extension: url.endsWith(".dmg") ? "dmg" : "html",
        file_name: url.split("/").pop() || url,
      });
    });
  }
}

/// Which call to action was taken, for the ones that stay on the site.
///
/// Outbound links are deliberately not marked. GA4's enhanced measurement
/// already logs those as `click` events, and marking them here would record
/// one action twice — which is worse than not recording it, because the
/// double is invisible in the report.
function trackCallsToAction(analytics) {
  for (const link of document.querySelectorAll("[data-cta]")) {
    link.addEventListener("click", () => {
      logEvent(analytics, "cta_click", { cta: link.dataset.cta });
    });
  }
}

/// How far into the page a reader actually got.
///
/// GA4's automatic `scroll` event fires once, at 90% — which answers "did
/// they reach the bottom" and nothing else. On a long guide the useful
/// question is where attention stopped, so each section reports itself once,
/// the first time it is genuinely on screen.
function trackSectionsRead(analytics) {
  const sections = document.querySelectorAll("section[id], h2[id]");
  if (!sections.length || !("IntersectionObserver" in window)) return;

  const observer = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (!entry.isIntersecting) continue;
        // Once each: a reader scrolling back up is not new interest.
        observer.unobserve(entry.target);
        logEvent(analytics, "section_read", {
          section: entry.target.id,
          page: document.location.pathname.split("/").pop() || "index.html",
        });
      }
    },
    // A heading clipping the bottom edge is not read. Requiring it to be a
    // third of the way up keeps a fast scroll from reporting the whole page.
    { rootMargin: "0px 0px -66% 0px" }
  );

  for (const section of sections) observer.observe(section);
}

async function startAnalytics() {
  // A consent gate belongs here: return early unless the visitor has agreed,
  // and call this again once they do. Nothing above this line touches the
  // browser's storage.

  // False in browsers that block the APIs the SDK needs — private modes,
  // hardened settings, some embedded webviews. Calling getAnalytics anyway
  // throws.
  if (!(await isSupported())) return;

  const analytics = getAnalytics(initializeApp(firebaseConfig));
  trackDownloads(analytics);
  trackCallsToAction(analytics);
  trackSectionsRead(analytics);
}

startAnalytics();
