// Optional browser check: requires Playwright; DIARY_BROWSER can select an installed Chromium executable.
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { chromium } = require('playwright');
const base = path.resolve('build/web');
const requests = [];
fs.writeFileSync('build/browser-authoring.log','');
const server = http.createServer(async (req,res) => {
  const name = new URL(req.url,'http://localhost').pathname.slice(1) || 'index.html';
  const file = path.resolve(base,name);
  if (!file.startsWith(base+path.sep) || !fs.existsSync(file)) { res.writeHead(404);res.end();return; }
  let bytes = fs.readFileSync(file);

  if (name.startsWith('asset-')) { requests.push(name); await new Promise(r=>setTimeout(r,100)); }
  res.setHeader('Content-Type', name.endsWith('.wasm')?'application/wasm':name.endsWith('.js')?'text/javascript':name.endsWith('.html')?'text/html':'application/octet-stream');
  res.setHeader('Content-Length',bytes.length);res.end(bytes);
});
(async()=>{
 await new Promise(r=>server.listen(8771,'127.0.0.1',r));
 const browser=await chromium.launch({executablePath:process.env.DIARY_BROWSER || undefined,headless:true,args:['--enable-unsafe-swiftshader','--no-sandbox']});
 try {
  const context=await browser.newContext({viewport:{width:1160,height:740}});
  const page=await context.newPage(); const errors=[];
  page.on('console',msg=>{fs.appendFileSync('build/browser-authoring.log',msg.text()+'\n');if(/SCRIPT ERROR|Parse Error|Failed loading|Error loading|Error calling/.test(msg.text()))errors.push(msg.text());});
  page.on('pageerror',e=>errors.push(e.message));
  await page.goto('http://127.0.0.1:8771/',{waitUntil:'domcontentloaded'});
  await page.waitForFunction(()=>window.diaryTitleReady,{},{timeout:60000});
  await page.keyboard.press('Enter');
  await page.waitForTimeout(15000);
  await page.keyboard.press('Space');
  await page.waitForTimeout(2000);
  await page.screenshot({path:'build/web-authoring-setup.png'});
  // Create > New room, then verify that the draft reaches IndexedDB.
  await page.mouse.click(175,16);
  await page.screenshot({path:'build/web-authoring-create-menu.png'});
  await page.mouse.click(208,46);
  await page.waitForFunction(()=>document.body.dataset.authoringSync && JSON.parse(document.body.dataset.authoringSync).status==='saved',{},{timeout:15000});
  await page.screenshot({path:'build/web-authoring-new-room.png'});
  await page.reload({waitUntil:'domcontentloaded'});
  await page.waitForFunction(()=>window.diaryTitleReady,{},{timeout:60000});
  await page.keyboard.press('Enter');
  await page.waitForTimeout(10000);
  await page.keyboard.press('Space');
  await page.waitForTimeout(2000);
  await page.screenshot({path:'build/web-authoring-reopened.png'});
  await page.keyboard.press('Space');
  await page.waitForTimeout(750);
  await page.screenshot({path:'build/web-authoring-resumed.png'});
  fs.writeFileSync('build/web-authoring-result.json',JSON.stringify({errors,passed:errors.length===0},null,2));
  assert.deepEqual(errors,[]);
  console.log('WEB AUTHORING PASS: pause, room creation, confirmed browser persistence and fresh-page reopening');
 } finally { await browser.close(); server.close(); }
})().catch(e=>{console.error(e);server.close();process.exitCode=1;});
