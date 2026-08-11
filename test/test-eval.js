const { JSDOM } = require('jsdom');
const dom = new JSDOM('<!DOCTYPE html><div id="root"></div>', { url: 'http://localhost/' });
global.window = dom.window;
global.document = dom.window.document;
global.navigator = dom.window.navigator;
global.self = dom.window;
global.localStorage = { getItem: ()=>null, setItem: ()=>{}, removeItem: ()=>{} };
global.sessionStorage = { getItem: ()=>null, setItem: ()=>{}, removeItem: ()=>{} };

const fs = require('fs');
const path = require('path');
const assetsDir = path.join(__dirname, 'dist/assets');
const files = fs.readdirSync(assetsDir);
const jsFiles = files.filter(f => f.endsWith('.js') && f.startsWith('index-'));

const mainJsFile = jsFiles[0];

import('file://' + path.join(assetsDir, mainJsFile))
  .then(() => console.log('Successfully loaded main js!'))
  .catch(err => console.error('Error loading main js:', err));
