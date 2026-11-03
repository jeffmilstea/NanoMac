import re, sys
samples=[]; cur={}
for line in open(sys.argv[1] if len(sys.argv)>1 else '/tmp/spin_osd.vcd'):
    line=line.rstrip('\n')
    if line.startswith('#'):
        if cur: samples.append(dict(cur))
        cur={}; continue
    m=re.match(r'b(\d+) ([a-z])',line)
    if m: cur[m.group(2)]=int(m.group(1),2); continue
    m=re.match(r'([01])\s*([a-z])\s*$',line)
    if m: cur[m.group(2)]=int(m.group(1)); continue
samples.append(dict(cur))
print(f"{len(samples)} samples")
for i,s in enumerate(samples):
    print(f"{i:3d} ph{s.get('p',0)} AS={s.get('s')} DT={s.get('k')} rw={'R' if s.get('w') else 'W'} ram={s.get('r')} rom={s.get('o')} A={s.get('a',0):06X} d={s.get('d',0):02X} hit={s.get('h')} en={s.get('e')} osd={s.get('c')} swp={s.get('v')}")
