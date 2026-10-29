// Blocks AI assistant tool calls that name a secrets file (.env, .mcp.json, key files, n8n's own folder).
// Second layer behind the deny rules in settings.json, which cover Claude's file tools.
// .env.example holds no secrets and stays readable.
let input = '';
process.stdin.on('data', c => (input += c));
process.stdin.on('end', () => {
  let call;
  try { call = JSON.parse(input); } catch { process.exit(0); }
  const text = JSON.stringify(call.tool_input ?? {});
  const secret = /(^|[^\w.])\.env(?!\.example)(?![\w])|\.mcp\.json|\.(key|pem)\b|credentials\.json|[\\/]\.n8n([\\/]|\b)|[\\/]\.ssh\b/;
  if (secret.test(text)) {
    process.stderr.write('Blocked: secrets (.env, .mcp.json, key files, ~/.n8n, ~/.ssh) are off limits.\n');
    process.exit(2);
  }
  process.exit(0);
});
