const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const xml = fs.readFileSync('packaging/Distribution.xml', 'utf8');
const source = xml.match(/<!\[CDATA\[([\s\S]*?)\]\]>/)[1];
function evaluate(installed, os = '15.6') {
  const context = {
    system: {
      version: { ProductVersion: os },
      files: { plistAtPath: () => installed ? { CFBundleShortVersionString: installed } : null },
      compareVersions: (a, b) => {
        const x=a.split('.').map(Number), y=b.split('.').map(Number);
        for(let i=0;i<Math.max(x.length,y.length);i++){
          const d=(x[i]||0)-(y[i]||0);if(d)return Math.sign(d);
        }return 0;
      }
    },my:{result:{}}
  };
  vm.createContext(context);vm.runInContext(source,context);return context;
}
assert.equal(evaluate(null).needsMacFUSE(), true);
assert.equal(evaluate('5.1.2').needsMacFUSE(), true);
assert.equal(evaluate('5.5.0').needsMacFUSE(), false);
assert.equal(evaluate('5.6.0').needsMacFUSE(), false);
assert.equal(evaluate('6.0.0').needsMacFUSE(), false);
assert.equal(evaluate('5.5.0','15.3').checkSystem(), false);
assert.equal(evaluate('5.5.0','15.4').checkSystem(), true);
assert.equal(evaluate('5.5.0','26.1').checkSystem(), true);
console.log('PASS: installer fresh/upgrade/preserve-newer and macOS requirements');
