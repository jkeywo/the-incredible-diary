// Optional browser check: requires Playwright; DIARY_BROWSER can select an installed Chromium executable.
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { chromium } = require('playwright');
const base = path.resolve('build/web');
const requests = [];
fs.writeFileSync('build/browser-stream.log','');
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
 await new Promise(r=>server.listen(8769,'127.0.0.1',r));
 const browser=await chromium.launch({executablePath:process.env.DIARY_BROWSER || undefined,headless:true,args:['--enable-unsafe-swiftshader','--no-sandbox']});
 try {
  const context=await browser.newContext({viewport:{width:1160,height:740}});
  const page=await context.newPage(); const errors=[];const logs=[];
  page.on('console',msg=>{logs.push(msg.text()); fs.appendFileSync("build/browser-stream.log",msg.text()+"\n"); if (/SCRIPT ERROR|Parse Error|Failed loading|Error loading|Error calling/.test(msg.text())) errors.push(msg.text());});
  page.on('pageerror',e=>errors.push(e.message));
  console.log('Browser started');
  await page.goto('http://127.0.0.1:8769/',{waitUntil:'domcontentloaded'});
  console.log('Page loaded');
  await page.screenshot({path:'build/web-initial.png',timeout:5000});
  await page.waitForFunction(()=>window.diaryTitleReady,{},{timeout:60000});
  console.log('Title ready');
  await page.screenshot({path:'build/web-title.png'});
  await page.keyboard.press('Enter');
  await page.waitForTimeout(200);
  await page.screenshot({path:'build/web-stream-wait.png'});
  await page.waitForTimeout(15000);
  await page.screenshot({path:'build/web-stream-docks.png'});
  const firstDocksRequests=[...requests];
  const first=requests.length;
  await page.reload({waitUntil:'domcontentloaded'});
  await page.waitForFunction(()=>window.diaryTitleReady,{},{timeout:60000});
  await page.keyboard.press('Enter');
  await page.waitForTimeout(10000);
  await page.screenshot({path:'build/web-stream-continue.png'});
  const repeated=requests.length-first;
  fs.writeFileSync('build/web-stream-result.json',JSON.stringify({first,firstDocksRequests,repeated,errors,logs},null,2));
  assert.deepEqual(errors,[]); assert.equal(repeated,0);
  const manifest=JSON.parse(fs.readFileSync('build/web-content-manifest.json','utf8'));
  for (const hash of manifest.resources['res://assets/rooms/mission_1/05_party_salon.tscn']) {
    assert(!firstDocksRequests.includes(manifest.packs[hash].url),'Unconnected salon downloaded too early');
  }
  const screenIndices=manifest.resources['res://assets/rooms/mission_1/02_foyer.tscn'].map(hash=>firstDocksRequests.indexOf(manifest.packs[hash].url));
  assert(screenIndices.every(index=>index>=0),'Neighbour screen was not prefetched');
  for (const resource of ['res://assets/characters/matron_sprites.png','res://assets/characters/glamorous_sprites.png']) {
    for (const hash of manifest.resources[resource]) {
      const index=firstDocksRequests.indexOf(manifest.packs[hash].url);
      assert(index>Math.max(...screenIndices),'Level characters must preload after screens');
    }
  }
  console.log(JSON.stringify({passed:true,first,repeated,firstDocks:firstDocksRequests.length}));
 } finally { await browser.close(); server.close(); }
})().catch(e=>{console.error(e);server.close();process.exitCode=1;});
