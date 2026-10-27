<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>Chat IA</title>
<style>
:root{--bg:#f6f5f2;--panel:#fff;--text:#1f1f1e;--muted:#6b6a66;--user:#d9532f;--userText:#fff;--bot:#ecebe6;--border:#e0ded8;--accent:#d9532f;
box-sizing:border-box;padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){--bg:#171716;--panel:#222221;--text:#ecebe6;--muted:#9a9890;--bot:#2e2e2c;--border:#38372f}}
:root[data-theme="dark"]{--bg:#171716;--panel:#222221;--text:#ecebe6;--muted:#9a9890;--bot:#2e2e2c;--border:#38372f}
*{box-sizing:border-box}
html,body{height:100%;margin:0}
body{background:var(--bg);color:var(--text);font:16px/1.5 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
.app{height:100%;max-width:760px;margin:0 auto;display:flex;flex-direction:column;background:var(--panel);border-left:1px solid var(--border);border-right:1px solid var(--border)}
header{padding:14px 18px;border-bottom:1px solid var(--border);display:flex;align-items:center;gap:10px}
header .dot{width:10px;height:10px;border-radius:50%;background:#3bb273}
header h1{font-size:17px;margin:0;flex:1}
header button{background:none;border:1px solid var(--border);color:var(--muted);border-radius:8px;padding:5px 10px;cursor:pointer;font:inherit;font-size:13px}
#log{flex:1;overflow-y:auto;padding:18px;display:flex;flex-direction:column;gap:12px}
.msg{max-width:82%;padding:10px 14px;border-radius:16px;white-space:pre-wrap;overflow-wrap:anywhere}
.bot{background:var(--bot);align-self:flex-start;border-bottom-left-radius:4px}
.me{background:var(--user);color:var(--userText);align-self:flex-end;border-bottom-right-radius:4px}
.err{color:#c0392b}
.chips{display:flex;flex-wrap:wrap;gap:8px}
.chips button{background:var(--bot);color:var(--text);border:1px solid var(--border);border-radius:999px;padding:7px 13px;cursor:pointer;font:inherit;font-size:14px}
form{display:flex;gap:8px;padding:12px 14px;border-top:1px solid var(--border)}
textarea{flex:1;resize:none;max-height:140px;border:1px solid var(--border);background:var(--bg);color:var(--text);border-radius:12px;padding:10px 12px;font:inherit}
textarea:focus{outline:2px solid var(--accent);outline-offset:-1px}
#send{background:var(--accent);color:#fff;border:0;border-radius:12px;padding:0 18px;font:inherit;font-weight:600;cursor:pointer}
#send:disabled{opacity:.5;cursor:default}
</style>
</head>
<body>
<div class="app">
  <header><span class="dot"></span><h1>Chat IA</h1><button id="clear" type="button">Nueva conversación</button></header>
  <div id="log" aria-live="polite"></div>
  <form id="f">
    <textarea id="in" rows="1" placeholder="Escribe tu mensaje…" aria-label="Mensaje"></textarea>
    <button id="send" type="submit">Enviar</button>
  </form>
</div>
<script>
(function(){
  var log=document.getElementById('log'),input=document.getElementById('in'),send=document.getElementById('send');
  var SYS='Eres un asistente de chat amable, claro y conciso. Responde siempre en el idioma del usuario (por defecto español). Usa texto plano, sin Markdown.';
  var history=[],sample=null,busy=false;
  var GREETING='¡Hola! Soy tu asistente de IA. Pregúntame lo que quieras.';
  var SUGGEST=['Cuéntame un dato curioso','Ayúdame a escribir un correo','Explícame algo sencillo'];

  function bubble(cls,text){
    var d=document.createElement('div');d.className='msg '+cls;d.textContent=text;
    log.appendChild(d);log.scrollTop=log.scrollHeight;return d;
  }
  function start(){
    log.textContent='';history=[];
    bubble('bot',GREETING);
    var c=document.createElement('div');c.className='chips';
    SUGGEST.forEach(function(s){
      var b=document.createElement('button');b.type='button';b.textContent=s;
      b.onclick=function(){c.remove();ask(s)};c.appendChild(b);
    });
    log.appendChild(c);
  }
  function payload(){
    return history.map(function(m,i){
      return {role:m.role,content:i===0?SYS+'\n\nMensaje del usuario: '+m.content:m.content};
    });
  }
  async function ask(text){
    if(busy||!text.trim())return;
    busy=true;send.disabled=true;
    bubble('me',text);history.push({role:'user',content:text});
    var out=bubble('bot','…');
    try{
      if(!sample)sample=await claude.use('sample');
      if(!sample){out.textContent='La IA no está disponible en esta vista. Ábrela desde claude.ai.';out.classList.add('err');history.pop();return}
      var r=await sample(payload(),{cache:false,onText:function(t){out.textContent=t.text;log.scrollTop=log.scrollHeight}});
      out.textContent=r.text;history.push({role:'assistant',content:r.text});
    }catch(e){
      out.textContent=(e&&e.code==='not_granted')?'Necesitas dar permiso para usar la IA.':(e&&e.code==='rate_limited')?'Demasiadas solicitudes, intenta en un momento.':'Ocurrió un error. Intenta de nuevo.';
      out.classList.add('err');history.pop();
    }finally{busy=false;send.disabled=false;input.focus();log.scrollTop=log.scrollHeight}
  }
  document.getElementById('f').addEventListener('submit',function(e){
    e.preventDefault();var t=input.value;input.value='';input.style.height='auto';ask(t);
  });
  input.addEventListener('keydown',function(e){
    if(e.key==='Enter'&&!e.shiftKey){e.preventDefault();document.getElementById('f').requestSubmit()}
  });
  input.addEventListener('input',function(){input.style.height='auto';input.style.height=Math.min(input.scrollHeight,140)+'px'});
  document.getElementById('clear').onclick=function(){if(!busy)start()};
  start();
})();
</script>
</body>
</html>