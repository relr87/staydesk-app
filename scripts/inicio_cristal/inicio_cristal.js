
/* Inicio de cristal (v26): envuelve el campo del ID o del PIN con su luz y su check, enciende el botón «Entrar»
   cuando el dato está completo, y al entrar a la app reproduce un efecto una sola vez.
   La validación, los mensajes de error y los bloqueos por intentos son los de siempre. */
(function(){
  const who=document.getElementById('who'),app=document.getElementById('app'),login=document.getElementById('login');if(!who)return;
  function okOf(inp){const v=(inp.value||'').trim();if(inp.id==='pin'){const L=+inp.maxLength>0?+inp.maxLength:4;return v.length>=Math.min(4,L)}return v.length>=2}
  function wire(form){
    const inp=form.querySelector('#uid,#pin');if(!inp||form.dataset.lx)return;form.dataset.lx='1';
    const f=document.createElement('span');f.className='lxf'+(inp.id==='pin'?' lxpin':'');inp.parentNode.insertBefore(f,inp);f.appendChild(inp);
    const ck=document.createElement('span');ck.className='lxck';ck.setAttribute('aria-hidden','true');ck.textContent='✓';f.appendChild(ck);
    const sync=()=>{const o=okOf(inp);f.classList.toggle('ok',o);form.classList.toggle('lxok',o)};
    inp.addEventListener('input',sync);sync()}
  const run=()=>who.querySelectorAll('form#lf1,form#lf2').forEach(wire);
  new MutationObserver(run).observe(who,{childList:true,subtree:true});run();

  /* the way into the app, "Polvo de oro" (in place of the old intro): the sign-in screen breaks into gold dust that flows into the logo,
     the logo pulses, the greeting shows, and the app appears. About 2.4 s; a tap, Enter or Esc skips it.
     The app's own switch for effects and "reduce motion" are respected: with either of them the app opens straight away, as before. */
  function fxOn(){const d=document.documentElement;return d.dataset.fx!=='0'&&d.dataset.motion!=='reduce'&&!matchMedia('(prefers-reduced-motion: reduce)').matches}
  function esc2(t){return String(t==null?'':t).replace(/[<>&"]/g,c=>({'<':'&lt;','>':'&gt;','&':'&amp;','"':'&quot;'}[c]))}
  /* the dust comes from what is really on the sign-in screen, each part in its own colour */
  const SRC=[['.lcard','#4B78B8',1],['#kc','#E8EEF7',1],['.lbrand .logo','#F5B13E',.6],['.lbrand .wmb','#F7A928',.7],['.lgreet','#C9D6EC',.8],
             ['.lhero h1','#FFFFFF',.7],['.lhero p','#C9D6EC',.9],['.lprop','#C9D6EC',.9],['.lcard .lxf','#13284A',1],['.lcard .lbtn','#F9A93A',.8],['.lcard .lp','#FFFFFF',.8],['.lcard .llinks','#F5C04A',.9]];
  function points(step){const P=[];
    for(const [sel,col,k] of SRC){for(const e of login.querySelectorAll(sel)){const r=e.getBoundingClientRect();if(!r.width||!r.height||r.bottom<0||r.top>innerHeight)continue;
      const st=Math.max(4,step*k);for(let y=r.top+st/2;y<r.bottom;y+=st)for(let x=r.left+st/2;x<r.right;x+=st)P.push({x,y,c:col,s:st*.9})}}
    for(let i=0;i<(innerWidth*innerHeight)/2600;i++)P.push({x:Math.random()*innerWidth,y:Math.random()*innerHeight,c:Math.random()<.5?'#2A5596':'#F5C04A',s:2});
    return P}
  if(typeof go==='function'){
    const prev=go;let busy=false;
    go=function(){
      const self=this,args=arguments;
      if(busy||!login||login.hidden||!fxOn()||(typeof RESUMING!=='undefined'&&RESUMING)||typeof me==='undefined'||!me)return prev.apply(self,args);
      busy=true;
      const en=/^en/i.test(document.documentElement.lang||''),W=innerWidth,H=innerHeight,dpr=Math.min(2,devicePixelRatio||1);
      const src=document.querySelector('#login .lbrand .logo svg');
      const svg=src?src.outerHTML.replace(/(id="|url\(#)L(\w+)/g,'$1Q$2'):'';     /* the copy gets its own ids, like the old intro did */
      const first=String(me.n||'').split(' ')[0],role=(me.r||'')+(typeof hm==='function'?' · '+hm():'');
      const o=document.createElement('div');o.className='lxfx fdust';o.setAttribute('aria-hidden','true');
      o.innerHTML=`<canvas></canvas><div class="lxlogo">${svg}</div><div class="lxname">${en?'Welcome':'Hola'}, ${esc2(first)}<small>${esc2(role)}</small></div><div class="lxskip">${en?'Tap to skip':'Toca para saltar'}</div>`;
      const cv=o.querySelector('canvas'),x=cv.getContext('2d');cv.width=W*dpr;cv.height=H*dpr;x.scale(dpr,dpr);
      const P=points(W<640?9:7),tx=W/2,ty=H*.44;
      P.forEach(p=>{p.d=Math.random()*420+(p.x/W)*260;p.w=Math.random()*6.28});
      document.body.appendChild(o);
      let opened=false,ended=false,raf=0;const T=[],t0=performance.now();
      const draw=now=>{const t=now-t0;x.globalAlpha=1;x.fillStyle='#071631';x.globalAlpha=Math.min(1,t/220);x.fillRect(0,0,W,H);x.globalAlpha=1;
        for(const p of P){const k=Math.min(1,Math.max(0,(t-p.d)/950)),e=k*k*(3-2*k),sw=Math.sin(p.w+t*.005)*26*(1-e)*k;
          const px=p.x+(tx-p.x)*e+sw,py=p.y+(ty-p.y)*e,sz=k>.08?Math.max(1.4,2.6*(1-k*.4)):p.s;
          x.globalAlpha=k>.08?1-k*.55:1;x.fillStyle=k>.08?`rgb(247,${178+Math.round(50*(1-k))},${60+Math.round(40*(1-k))})`:p.c;x.fillRect(px-sz/2,py-sz/2,sz,sz)}
        x.globalAlpha=1;if(t<1700&&!ended)raf=requestAnimationFrame(draw)};
      raf=requestAnimationFrame(draw);
      const open=()=>{if(opened)return;opened=true;login.hidden=true;try{prev.apply(self,args)}catch(e){console.error(e)}   /* with the sign-in screen hidden, the old intro steps aside and the app opens straight away */
        document.body.classList.add('lxin');setTimeout(()=>document.body.classList.remove('lxin'),1200)};
      const end=()=>{if(ended)return;ended=true;cancelAnimationFrame(raf);open();T.forEach(clearTimeout);o.remove();document.removeEventListener('keydown',key,true);busy=false};
      const key=e=>{if(e.key==='Enter'||e.key===' '||e.key==='Escape'){e.preventDefault();e.stopPropagation();end()}};
      o.addEventListener('click',end);document.addEventListener('keydown',key,true);
      T.push(setTimeout(()=>o.classList.add('lit'),1250));   /* the logo forms where the dust meets */
      T.push(setTimeout(open,1650),setTimeout(()=>o.classList.add('out'),1750),setTimeout(end,2450))};
  }
  /* sounds at sign-in: only the desk-bell "ding" of the key card when the PIN is accepted. For 3 s from that moment the alert tones
     (pending notices, guest chat) stay quiet; the notices still show, and later alerts sound as usual. */
  let quietUntil=0;
  if(typeof playSnd==='function'){const ps=playSnd;playSnd=function(k,force){if(Date.now()<quietUntil&&!force)return false;return ps.apply(this,arguments)}}
  if(typeof buzz==='function'){const bz=buzz;buzz=function(){if(Date.now()<quietUntil)return;return bz.apply(this,arguments)}}
  if(typeof showBrief==='function'){const sb=showBrief;showBrief=function(){if(login&&!login.hidden)quietUntil=Date.now()+3000;return sb.apply(this,arguments)}}
})();
