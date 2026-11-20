
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

  /* the way into the app, in place of the old one: a layer covers the sign-in screen, the app opens underneath, the layer plays out.
     Which one: ?fx=a|b|c in the address, else the saved choice, else A. The app's own switch for effects and "reduce motion" are respected. */
  function pick(){let v='';try{v=new URLSearchParams(location.search).get('fx')||localStorage.getItem('staydesk.lxfx')||''}catch(_){}return /^[abc]$/.test(v)?v:'a'}
  function fxOn(){const d=document.documentElement;return d.dataset.fx!=='0'&&d.dataset.motion!=='reduce'&&!matchMedia('(prefers-reduced-motion: reduce)').matches}
  function esc2(t){return String(t==null?'':t).replace(/[<>&"]/g,c=>({'<':'&lt;','>':'&gt;','&':'&amp;','"':'&quot;'}[c]))}
  if(typeof go==='function'){
    const prev=go;let busy=false;
    go=function(){
      const self=this,args=arguments;
      if(busy||!login||login.hidden||!fxOn()||(typeof RESUMING!=='undefined'&&RESUMING)||typeof me==='undefined'||!me)return prev.apply(self,args);
      busy=true;
      const k=pick(),en=/^en/i.test(document.documentElement.lang||'');
      const src=document.querySelector('#login .lbrand .logo svg');
      const svg=src?src.outerHTML.replace(/(id="|url\(#)L(\w+)/g,'$1Q$2'):'';     /* the copy gets its own ids, like the old intro did */
      const first=String(me.n||'').split(' ')[0],role=(me.r||'')+(typeof hm==='function'?' · '+hm():'');
      const name=`<div class="lxname">${en?'Welcome':'Hola'}, ${esc2(first)}<small>${esc2(role)}</small></div>`;
      const L=`<div class="lxlogo">${svg}</div>`,skip=`<div class="lxskip">${en?'Tap to skip':'Toca para saltar'}</div>`;
      const o=document.createElement('div');o.className='lxfx f'+k;o.setAttribute('aria-hidden','true');
      o.innerHTML=k==='b'?`<div class="lxd lxdl">${L}${name}</div><div class="lxd lxdr">${L}${name}</div><div class="lxseam"></div>${skip}`:L+name+skip;
      document.body.appendChild(o);
      let opened=false,ended=false;const T=[];
      const open=()=>{if(opened)return;opened=true;login.hidden=true;try{prev.apply(self,args)}catch(e){console.error(e)}   /* with the sign-in screen hidden, the old intro steps aside and the app opens straight away */
        if(k==='c'){document.body.classList.add('lxrise');setTimeout(()=>document.body.classList.remove('lxrise'),1400)}};
      const end=()=>{if(ended)return;ended=true;open();T.forEach(clearTimeout);o.remove();document.removeEventListener('keydown',key,true);busy=false};
      const key=e=>{if(e.key==='Enter'||e.key===' '||e.key==='Escape'){e.preventDefault();e.stopPropagation();end()}};
      o.addEventListener('click',end);document.addEventListener('keydown',key,true);
      T.push(setTimeout(()=>{try{if(typeof lxSnd==='function')lxSnd()}catch(_){}},k==='b'?640:560));   /* the app's own desk bell, as before */
      T.push(setTimeout(open,640),setTimeout(end,2250))};
  }
})();
