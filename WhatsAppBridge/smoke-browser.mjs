// Packaging check only: open a blank page, never WhatsApp or a user's session.
import fs from 'node:fs';
import path from 'node:path';
import puppeteer from 'puppeteer';
const candidates = [path.join(process.env['ProgramFiles(x86)'] || '', 'Microsoft/Edge/Application/msedge.exe'),
  path.join(process.env.ProgramFiles || '', 'Microsoft/Edge/Application/msedge.exe')];
const executablePath = candidates.find(p => fs.existsSync(p));
if (!executablePath) throw new Error('Microsoft Edge not found');
const browser = await puppeteer.launch({ executablePath, headless: true });
try { const page = await browser.newPage(); await page.goto('about:blank'); console.log('Windows browser started with default sandbox.'); }
finally { await browser.close(); }
