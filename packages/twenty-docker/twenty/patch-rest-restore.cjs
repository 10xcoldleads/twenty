const assert = require('node:assert/strict');
const fs = require('node:fs');

const parserPath =
  '/app/packages/twenty-server/dist/engine/api/rest/input-request-parsers/path-parser-utils/parse-core-path.utils.js';

const vulnerable = `if (queryAction.length > 2 ||
        (queryAction.length > 3 && queryAction[0] === 'restore')) {`;
const corrected = `const isRestoreRequest = queryAction[0] === 'restore';
    if ((!isRestoreRequest && queryAction.length > 2) ||
        (isRestoreRequest && queryAction.length > 3)) {`;

const source = fs.readFileSync(parserPath, 'utf8');
const matches = source.split(vulnerable).length - 1;

assert.equal(
  matches,
  1,
  `Expected exactly one vulnerable REST restore condition, found ${matches}`,
);

fs.writeFileSync(parserPath, source.replace(vulnerable, corrected));

const { parseCorePath } = require(parserPath);
const id = '20202020-2020-4020-8020-202020202020';

assert.deepEqual(
  parseCorePath({ path: `/rest/restore/companies/${id}` }),
  { object: 'companies', id },
);
assert.deepEqual(parseCorePath({ path: '/rest/restore/companies' }), {
  object: 'companies',
  id: undefined,
});
assert.throws(() =>
  parseCorePath({ path: `/rest/restore/companies/${id}/extra` }),
);

console.log('REST restore parser patched and verified.');
