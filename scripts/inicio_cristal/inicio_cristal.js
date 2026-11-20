/* Inicio de cristal (v26): envuelve el campo del ID o del PIN con su luz y su check, y ata el botón «Entrar» a su ancla.
   El botón escapa del puntero mientras falta el dato; con el dato completo vuelve al centro y se enciende.
   Enter y el teclado siguen funcionando igual; la validación y los mensajes de error son los de siempre. */
(function(){
  const who=document.getElementById('who');if(!who)return;
  const NS='http://www.w3.org/2000/svg';
  function okOf(inp){const v=(inp.value||'').trim();if(inp.id==='pin'){const L=+inp.maxLength>0?+inp.maxLength:4;return v.length>=Math.min(4,L)}return v.length>=2}
  function wire(form){
    const inp=form.querySelector('#uid,#pin'),btn=form.querySelector('.lbtn');if(!inp||!btn||form.dataset.lx)return;form.dataset.lx='1';
    const f=document.createElement('span');f.className='lxf'+(inp.id==='pin'?' lxpin':'');inp.parentNode.insertBefore(f,inp);f.appendChild(inp);
    const ck=document.createElement('span');ck.className='lxck';ck.setAttribute('aria-hidden','true');ck.textContent='✓';f.appendChild(ck);
    const dock=document.createElement('div');dock.className='lxdock';btn.parentNode.insertBefore(dock,btn);
    const svg=document.createElementNS(NS,'svg');svg.setAttribute('aria-hidden','true');const an=document.createElementNS(NS,'circle');an.setAttribute('class','lxan');an.setAttribute('r','7');
    const te=document.createElementNS(NS,'path');te.setAttribute('class','lxte');svg.append(an,te);dock.append(svg,btn);
    const hint=document.createElement('p');hint.className='lxhint';hint.setAttribute('aria-live','polite');dock.after(hint);
    let bx=0,by=0,ok=false;
    const place=()=>{const w=dock.clientWidth,h=dock.clientHeight;if(!w)return;btn.style.translate=`${bx}px ${by}px`;btn.style.rotate=`${ok?0:bx*.04}deg`;
      const ax=w/2-60,ay=h/2,ex=w/2-75+bx+8,ey=h/2+by;an.setAttribute('cx',ax);an.setAttribute('cy',ay);
      te.setAttribute('d',`M ${ax+7} ${ay} Q ${(ax+ex)/2} ${Math.max(ay,ey)+18} ${ex} ${ey}`)};
    const sync=()=>{const o=okOf(inp);f.classList.toggle('ok',o);dock.classList.toggle('ok',o);
      const en=/^en/i.test(document.documentElement.lang||'');
      hint.textContent=o?(en?'Ready. You can sign in now.':'Listo. Ya puedes entrar.'):inp.id==='pin'?(en?'Type your PIN to catch the button.':'Escribe tu PIN para atrapar el botón.'):(en?'Type your ID to catch the button.':'Escribe tu ID para atrapar el botón.');hint.classList.toggle('ok',o);
      if(o&&!ok){bx=0;by=0}ok=o;place()};
    const flee=(px,py)=>{if(ok)return;const r=dock.getBoundingClientRect(),w=r.width,h=r.height,cx=r.left+w/2+bx,cy=r.top+h/2+by,dx=cx-px,dy=cy-py,d=Math.hypot(dx,dy);
      if(d>120)return;const lim=w/2-85;let nx=bx+(dx/(d||1))*90,ny=by+(dy/(d||1))*14;if(Math.abs(nx)>lim)nx=-Math.sign(nx)*lim*.6;by=Math.max(-10,Math.min(10,ny));bx=nx;place()};
    dock.addEventListener('pointermove',e=>flee(e.clientX,e.clientY));
    btn.addEventListener('pointerdown',e=>{if(!ok){e.preventDefault();flee(e.clientX+(Math.random()<.5?-20:20),e.clientY)}});
    btn.addEventListener('click',e=>{if(!ok&&e.detail>0){e.preventDefault()}});   /* a mouse or finger cannot press it before the field is filled; Enter still sends the form */
    inp.addEventListener('input',sync);addEventListener('resize',place);SY.push(sync);requestAnimationFrame(sync)}
  const SY=[];   /* the hints follow the ES / EN switch */
  new MutationObserver(()=>SY.forEach(f=>{try{f()}catch(_){}})).observe(document.documentElement,{attributes:true,attributeFilter:['lang']});
  const run=()=>who.querySelectorAll('form#lf1,form#lf2').forEach(wire);
  new MutationObserver(run).observe(who,{childList:true,subtree:true});run();
})();
