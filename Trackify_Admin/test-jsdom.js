const fs = require('fs');
const path = require('path');
const { JSDOM } = require('jsdom');

const html = fs.readFileSync(path.join(__dirname, 'dist/index.html'), 'utf8');

const dom = new JSDOM(html, {
  url: 'http://localhost/',
  runScripts: 'dangerously',
  resources: 'usable',
  pretendToBeVisual: true
});

dom.window.addEventListener('error', (event) => {
  console.log('JSDOM Error Event:', event.error);
});
dom.window.addEventListener('unhandledrejection', (event) => {
  console.log('JSDOM Unhandled Rejection:', event.reason);
});
dom.window.console.error = (...args) => console.log('JSDOM Console Error:', ...args);
dom.window.console.warn = (...args) => console.log('JSDOM Console Warn:', ...args);

setTimeout(() => {
  console.log('JSDOM Script complete.');
}, 2000);
