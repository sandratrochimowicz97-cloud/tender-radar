// Smoke test: starts the server the way Claude does, lists its tools and calls each one once.
// Run from the repo root: node mcp/smoke-test.mjs   (the database and .env must be set up as in the README)
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { fileURLToPath } from 'node:url';

const client = new Client({ name: 'smoke-test', version: '1.0.0' });
await client.connect(new StdioClientTransport({
  command: process.execPath, args: [fileURLToPath(new URL('./server.mjs', import.meta.url))],
  env: { ...process.env },
}));
const { tools } = await client.listTools();
console.log('Tools:', tools.map(t => t.name).join(', '));
const show = (name, res) => {
  if (res.isError) { console.log(`${name}: ERROR ${res.content[0].text}`); process.exitCode = 1; return; }
  const body = JSON.parse(res.content[0].text);
  console.log(`${name}: ${body.count} tender(s)`, body.tenders?.[0] ? `first: ${body.tenders[0].verdict}, ${body.tenders[0].deadline}` : '');
};
show('list_tenders', await client.callTool({ name: 'list_tenders', arguments: { limit: 5 } }));
show('list_tenders GO in 30 days', await client.callTool({ name: 'list_tenders', arguments: { verdict: 'GO', closing_within_days: 30 } }));
show('search_tenders', await client.callTool({ name: 'search_tenders', arguments: { text: 'schul' } }));
const one = await client.callTool({ name: 'list_tenders', arguments: { limit: 1 } });
const first = one.isError ? null : JSON.parse(one.content[0].text).tenders[0];
if (first) show('get_tender', await client.callTool({ name: 'get_tender', arguments: { notice_id: first.notice_id } }));
await client.close();
