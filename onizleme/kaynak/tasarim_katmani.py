import sys,re
MARK='/* EZAN-TASARIM-V2 */'
krem=open('logo_krem.b64').read();yesil=open('logo_yesil.b64').read()
CSS='''<style>'''+MARK+'''
.app[data-t="yesil"]{--page:#000e09;--paper:#021a12;--paper2:#00120c;--chip:#00140e;--pill:#021a12;--line:rgba(212,175,55,.45);background:radial-gradient(90% 55% at 50% 16%,#06281c 0%,#011810 45%,#000a06 100%) fixed!important}
.app[data-t="yesil"] .view{background:transparent}
.app[data-t="yesil"] button:not(.on){box-shadow:inset 0 1px 0 rgba(255,230,160,.10),0 2px 6px rgba(0,0,0,.45)}
.app button.on{background:linear-gradient(180deg,#6e5114 0%,#4a3508 50%,#2a1c03 100%)!important;color:#ffe08a!important;border-color:#f0c75e!important;box-shadow:0 0 12px rgba(240,199,94,.45),inset 0 1px 0 rgba(255,236,170,.35)!important}
.app button.on svg,.app button.on small,.app button.on b{color:#ffe08a!important}
.hdr .top .mid{display:flex;align-items:center;justify-content:center}
.hdr .top .mid>*{display:none!important}
.hdr .top .mid::after{content:"";display:block;width:84px;height:84px;background:url('''+krem+''') center/contain no-repeat;filter:drop-shadow(0 2px 4px rgba(0,0,0,.5))}
.app[data-t="yesil"] .hdr .top .mid::after{background-image:url('''+yesil+''')}
</style>'''
for f in sys.argv[1:]:
    s=open(f).read()
    if MARK in s: print('skip',f); continue
    s=s.replace('linear-gradient(180deg,#0b3f2b,#052418)','linear-gradient(180deg,#0a3525 0%,#01170f 55%,#000c07 100%)')
    i=s.find('<div class="app"')
    s=s[:i]+CSS+'\n'+s[i:]
    open(f,'w').write(s);print('ok',f)
