const puppeteer = require('puppeteer-core');
(async () => {
  try {
    const browser = await puppeteer.launch({
      executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
      headless: 'new'
    });
    const page = await browser.newPage();
    page.on('console', msg => console.log('PAGE LOG:', msg.text()));
    page.on('pageerror', error => console.log('PAGE ERROR:', error.message));
    page.on('requestfailed', request =>
      console.log('REQUEST FAILED:', request.url(), request.failure().errorText)
    );
    await page.goto('https://ys-trackify-pnvpm0t58-tanvirrpatel4801-5669s-projects.vercel.app/', { waitUntil: 'networkidle0' });
    const bodyHTML = await page.evaluate(() => document.body.innerHTML);
    console.log('BODY HTML:', bodyHTML.substring(0, 500));
    await browser.close();
  } catch (err) {
    console.error('PUPPETEER ERROR:', err);
  }
})();
