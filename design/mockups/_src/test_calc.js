// Invariant tests for calc.js (run: node test_calc.js)
const assert = require('assert');
const C = require('./calc.js');

const people = [{id:'a'},{id:'b'},{id:'c'},{id:'d'}];
const items = [
  {id:1, price:1400, who:['a','b','c']},
  {id:2, price:1650, who:['a']},
  {id:3, price:1500, who:['b']},
  {id:4, price:1150, who:['c']},
  {id:5, price:1350, who:['d']},
  {id:6, price:800,  who:['b']},
  {id:7, price:350,  who:['d']},
  {id:8, price:900,  who:['a','b','c','d']},
];

// splitEqual
assert.deepStrictEqual(C.splitEqual(1400,['a','b','c']), {a:467,b:467,c:466});
assert.deepStrictEqual(C.splitEqual(1200,['a','b','c']), {a:400,b:400,c:400});

// allocate: sums exact, ties by order
let al = C.allocate(100,[1,1,1]);
assert.strictEqual(al.shares.reduce((x,y)=>x+y,0),100);
assert.deepStrictEqual(al.shares,[34,33,33]);
assert.deepStrictEqual(C.allocate(0,[1,2]).shares,[0,0]);
assert.deepStrictEqual(C.allocate(50,[0,0]).shares,[0,0]);
// zero-subtotal person gets nothing
assert.deepStrictEqual(C.allocate(10,[0,5,5]).shares,[0,5,5]);

// tip rounding half up
assert.strictEqual(C.tipFromPct(9100,18),1638);
assert.strictEqual(C.tipFromPct(9100,15),1365);
assert.strictEqual(C.tipFromPct(1001,15),150);   // 150.15 -> 150
assert.strictEqual(C.tipFromPct(1030,15),155);   // 154.5 -> 155 (half up)

// full bill
const tax = 751, tip = C.tipFromPct(9100,18);
const bill = C.computeBill({items, people, tax, tip});
const sum = (a)=>a.reduce((x,y)=>x+y,0);
assert.strictEqual(bill.unassigned.length,0);
assert.strictEqual(sum(bill.rows.map(r=>r.items)),9100);
assert.strictEqual(sum(bill.rows.map(r=>r.tax)),tax);
assert.strictEqual(sum(bill.rows.map(r=>r.tip)),tip);
assert.strictEqual(sum(bill.rows.map(r=>r.total)),9100+tax+tip);
assert.strictEqual(bill.total, 9100+tax+tip);
// determinism
assert.deepStrictEqual(C.computeBill({items,people,tax,tip}), bill);

// unassigned items are reported and not counted
const partial = items.map(i=>i.id===7?{...i,who:[]}:i);
const b2 = C.computeBill({items:partial, people, tax, tip});
assert.deepStrictEqual(b2.unassigned.map(i=>i.id),[7]);
assert.strictEqual(sum(b2.rows.map(r=>r.items)),9100-350);

// Puerto Rico sample (Fonda Dona Lola): tax 11.5% = 11.62, tip 18% pre-tax
(function(){
  const pp=[{id:'a'},{id:'b'},{id:'c'},{id:'d'}];
  const its=[
    {id:1,price:400,who:['d']},{id:2,price:500,who:['b']},{id:3,price:1400,who:['a','b','c']},
    {id:4,price:2200,who:['a']},{id:5,price:1800,who:['b']},{id:6,price:1400,who:['c']},
    {id:7,price:1500,who:['d']},{id:8,price:900,who:['a','b','c','d']}];
  assert.strictEqual(its.reduce((s,i)=>s+i.price,0),10100);
  const tipPR=C.tipFromPct(10100,18); assert.strictEqual(tipPR,1818);
  const bPR=C.computeBill({items:its,people:pp,tax:1162,tip:tipPR});
  assert.strictEqual(bPR.total,10100+1162+1818);
  assert.strictEqual(bPR.rows.reduce((s,r)=>s+r.total,0),13080);
  // service charge pool: allocated by item subtotal, included in totals
  const bS=C.computeBill({items:its,people:pp,tax:1162,service:1515,tip:0});
  assert.strictEqual(bS.service,1515);
  assert.strictEqual(bS.total,10100+1162+1515);
  for (const r of bS.rows) assert.strictEqual(r.total,r.items+r.tax+r.service+r.tip);
  // no service => unchanged results
  assert.deepStrictEqual(C.computeBill({items:its,people:pp,tax:1162,tip:tipPR}).rows.map(r=>r.total), bPR.rows.map(r=>r.total));
  console.log('PR per person', bPR.rows.map(r=>[r.items,r.tax,r.tip,r.total,r.itemAdj.length,r.taxAdj,r.tipAdj].join('/')).join('  '));
})();

// property: random bills always reconcile exactly
let seed = 12345; const rnd = ()=> (seed = (seed*1103515245+12345) & 0x7fffffff) / 0x7fffffff;
for (let t=0;t<2000;t++){
  const np = 1+Math.floor(rnd()*6), ps = Array.from({length:np},(_,i)=>({id:'p'+i}));
  const ni = 1+Math.floor(rnd()*9);
  const its = Array.from({length:ni},(_,i)=>({id:i,price:1+Math.floor(rnd()*9000),
    who:ps.filter(()=>rnd()<0.5).map(p=>p.id)}));
  const sub = its.reduce((s,i)=>s+i.price,0);
  const tx = Math.floor(rnd()*sub*0.12), tp = C.tipFromPct(sub, 15+Math.floor(rnd()*10));
  const bl = C.computeBill({items:its, people:ps, tax:tx, tip:tp});
  const assigned = its.filter(i=>i.who.length).reduce((s,i)=>s+i.price,0);
  assert.strictEqual(sum(bl.rows.map(r=>r.items)), assigned);
  if (assigned>0){
    assert.strictEqual(sum(bl.rows.map(r=>r.tax)), tx);
    assert.strictEqual(sum(bl.rows.map(r=>r.tip)), tp);
  }
  for (const r of bl.rows) assert.strictEqual(r.total, r.items+r.tax+r.tip);
}
console.log('calc tests passed');
