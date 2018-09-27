---
layout: page
title: IRC
---

# FixMyStreet chat

<script>
// clock added so folk know what time it is in Blighty
// Anytime Anywhere Web Page Clock Generator
// Clock Script Generated at
// http://rainbow.arch.scriptmania.com/tools/clock/clock_generator.html

function tS(){ x=new Date(tN().getUTCFullYear(),tN().getUTCMonth(),tN().getUTCDate(),tN().getUTCHours(),tN().getUTCMinutes(),tN().getUTCSeconds()); x.setTime(x.getTime()+dS()+0); return x; } 
function tN(){ return new Date(); } 
function dS(){ return ((tN().getTime()>fD(0,2,2,-1).getTime())&&(tN().getTime()<fD(0,9,3,-1).getTime()))?3600000:0; } 
function fD(d,m,h,p){ var week=(p<0)?7*(p+1):7*(p-1),nm=(p<0)?m+1:m,x=new Date(tN().getUTCFullYear(),nm,1,h,0,0),dOff=0; if(p<0){ x.setTime(x.getTime()-86400000); } if(x.getDay()!=d){ dOff=(x.getDay()<d)?(d-x.getDay()):0-(x.getDay()-d); if(p<0&&dOff>0){ week-=7; } if(p>0&&dOff<0){ week+=7; } x.setTime(x.getTime()+((dOff+week)*86400000)); } return x; } 
function lZ(x){ return (x>9)?x:'0'+x; } 
function dE(x){ if(x==1||x==21||x==31){ return 'st'; } if(x==2||x==22){ return 'nd'; } if(x==3||x==23){ return 'rd'; } return 'th'; } 
function dT(){ if(fr==0){ fr=1; document.write('<span id="tP">'+eval(oT)+'</span>'); } document.getElementById('tP').innerHTML=eval(oT); setTimeout('dT()',1000); } 
function y4(x){ return (x<500)?x+1900:x; } 
var dN=new Array('Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'),mN=new Array('January','February','March','April','May','June','July','August','September','October','November','December'),fr=0,oT="dN[tS().getDay()]+' '+tS().getDate()+dE(tS().getDate())+' '+mN[tS().getMonth()]+' '+y4(tS().getYear())+' '+':'+':'+' '+lZ(tS().getHours())+':'+lZ(tS().getMinutes())";
</script>

To connect to our <acronym title="Internet Relay Chat">IRC</acronym> channel
(chat room), either choose a nickname below, provided by Mibbit, or if you know
about IRC and have a client already, connect to irc.freenode.net and enter the
#fixmystreet channel.

<p>mySociety is mainly based in the UK, so you may find the 
IRC channel ('chatroom') quiet sometimes.
The time in the UK now is
<script>dT();</script></p>

<iframe width="600" height="480" scrolling="no" frameborder="0"
  src="https://webchat.freenode.net/?channels=%23fixmystreet&randomnick=1">
  </iframe>
