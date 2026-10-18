"""Render SpaceRacer's audio. Python + numpy + ffmpeg; no network needed.
Inputs and published CC0 source evidence are in tools/audio_sources.

Every sound is a recipe: a function of a few numbers. Defaults live in
RECIPES; tools/audio_params.json (written by tools/audio_search.py, the AI
judge loop) overrides them. See tools/audio_loop.md.
"""
from pathlib import Path
import hashlib, json, subprocess, wave, zipfile
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'tools/audio_sources'
OUT=ROOT/'assets/audio/racer'
PARAMS=ROOT/'tools/audio_params.json'
SR=48000
MANIFEST=[]
def decode(data):
    raw=subprocess.check_output(['ffmpeg','-v','error','-i','pipe:0','-ac','1','-ar',str(SR),'-f','f32le','pipe:1'],input=data)
    return np.frombuffer(raw,dtype='<f4').astype(float)
def band(x,lo,hi):
    f=np.fft.rfftfreq(len(x),1/SR)
    response=(1/(1+(lo/np.maximum(f,.01))**4))*(1/(1+(f/hi)**6))
    return np.fft.irfft(np.fft.rfft(x)*response,n=len(x))
def norm(x,rms=.2):
    x=x-np.mean(x)
    return x*(rms/max(1e-9,np.sqrt(np.mean(x*x))))
def fit(x,n,rate=1.):
    return np.interp(np.arange(n)*rate,np.arange(len(x)),x,left=0,right=0)
def seam(x,seconds=.20):
    n=int(seconds*SR); y=x[n:].copy(); w=np.sin(np.linspace(0,np.pi/2,n))**2
    y[-n:]=x[-n:]*(1-w)+x[:n]*w
    return y

def finish(x,loop=False):
    x=x-np.mean(x)
    if not loop:
        a=min(int(.003*SR),len(x)//4);b=min(int(.06*SR),len(x)//4)
        x[:a]*=np.linspace(0,1,a);x[-b:]*=np.linspace(1,0,b)
    return x*min(1,.82/max(1e-9,np.max(np.abs(x))))

def save(name,x,sources,loop=False):
    x=finish(x,loop)
    p=OUT/(name+'.wav')
    with wave.open(str(p),'wb') as w:
        w.setparams((1,2,SR,0,'NONE','not compressed')); w.writeframes((x*32767).astype('<i2').tobytes())
    settings=p.with_suffix('.wav.import')
    if settings.exists():
        settings.write_text(settings.read_text().replace('compress/mode=2','compress/mode=0'),encoding='utf8')
    else:
        settings.write_text('[remap]\nimporter="wav"\ntype="AudioStreamWAV"\n[params]\ncompress/mode=0\n',encoding='utf8')
    MANIFEST.append(dict(file=p.relative_to(ROOT).as_posix(),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),seconds=len(x)/SR,peak=float(np.max(abs(x))),rms=float(np.sqrt(np.mean(x*x))),loop=loop,sources=sources))

# Synthesis helpers. Loops use partials on a 1/L Hz grid so they wrap exactly.
def on_grid(f,length): return np.round(f*length)/length
def additive(freqs,amps,n,rng,length=None):
    t=np.arange(n)/SR; x=np.zeros(n)
    for f,a in zip(freqs,amps):
        if f<=0 or f>=SR*.45: continue
        if length: f=on_grid(f,length)
        x+=a*np.sin(2*np.pi*f*t+rng.uniform(0,2*np.pi))
    return x
def chirp(f0,f1,n,curve=1.,harmonics=(1.,)):
    t=np.arange(n)/SR; u=t/max(t[-1],1e-9)
    f=f0+(f1-f0)*u**curve; phase=2*np.pi*np.cumsum(f)/SR; x=np.zeros(n)
    for k,a in enumerate(harmonics,1):
        x+=a*np.sin(k*phase)*(f*k<SR*.45)
    return x
def lowpass(x,cutoff):
    # One-pole low-pass with a per-sample cutoff (Hz), for sweeps.
    c=np.broadcast_to(np.asarray(cutoff,float),x.shape)
    a=1-np.exp(-2*np.pi*c/SR); y=np.empty_like(x); s=0.
    for i in range(len(x)): s+=a[i]*(x[i]-s); y[i]=s
    return y
def comb(x,delay_s,mix=.6):
    # Flanger: a moving short delay mixed back in.
    idx=np.arange(len(x))-np.asarray(delay_s)*SR
    return x+mix*np.interp(idx,np.arange(len(x)),x,left=0)
def env(n,attack,decay):
    t=np.arange(n)/SR
    return np.minimum(1,t/max(attack,1e-4))*np.exp(-t*decay)
def crackle(n,rng,density,lo,hi):
    # Sparse random impulses through a band: electric sparks and debris.
    x=np.zeros(n); d=np.broadcast_to(np.asarray(density,float),(n,))
    hits=rng.random(n)<d/SR; x[hits]=rng.choice([-1,1],hits.sum())*rng.uniform(.3,1,hits.sum())
    return band(x,lo,hi)
def tone(f,n,detune=.004,odd=5):
    # Bright two-oscillator synth voice (band-limited square-ish).
    t=np.arange(n)/SR; x=np.zeros(n)
    for d in (1-detune,1+detune):
        for k in range(1,2*odd,2):
            if f*d*k<SR*.45: x+=np.sin(2*np.pi*f*d*k*t)/k
    return x
def loop_of(x,seconds=.2):
    return seam(np.concatenate([x,x[:int(seconds*SR)]]),seconds)

class Sources:
    _jet=None;_mats=None
    @classmethod
    def jet(cls):
        if cls._jet is None: cls._jet=decode((SRC/'152509.mp3').read_bytes())
        return cls._jet
    @classmethod
    def material(cls,kind,i,n,rate=1.):
        if cls._mats is None:
            z=zipfile.ZipFile(SRC/'kenney-impact.zip')
            cls._mats={k:[decode(z.read(f'Audio/{v}_{j:03}.ogg')) for j in range(5)] for k,v in [('metal','impactMetal_heavy'),('heavy','impactPunch_heavy')]}
        return fit(band(cls._mats[kind][i%5],65,9000),n,rate)

# --- Recipes: name -> (function(p, rng, variant) -> samples, defaults, loop, sources)
def r_drive(p,rng,i):
    L=4.;n=int(L*SR);t=np.arange(n)/SR;f0=p['f0'];k=np.arange(1,int(9000/f0))
    amps=1/k**p['roll']*(1+p['f1g']*np.exp(-((f0*k-p['f1'])/(p['f1']*.4))**2)+p['f2g']*np.exp(-((f0*k-p['f2'])/(p['f2']*.25))**2))
    turbine=additive(f0*k,amps,n,rng,L)
    sub=additive([f0/2,f0],[1,.5],n,rng,L)*(1+.5*np.sin(2*np.pi*on_grid(f0/4,L)*t))
    whine=sum(a*np.sin(2*np.pi*on_grid(f0*r,L)*t+p['vib']*np.sin(2*np.pi*on_grid(5.,L)*t+r)) for r,a in [(23.5,.5),(31.25,.32),(38.5,.18)])
    exhaust=band(rng.normal(size=n),p['nlo'],p['nhi'])*(1+p['pulse']*np.sin(2*np.pi*on_grid(f0/2,L)*t))
    texture=band(Sources.jet()[20*SR:20*SR+n],100,12000)
    return loop_of(norm(turbine,.15)+norm(sub,.15*p['sub']+1e-6)+norm(whine,.1*p['whine']+1e-6)+norm(exhaust,.1*p['noise']+1e-6)+norm(texture,.1*p['jet']+1e-6))
def r_idle(p,rng,i):
    L=2.;n=int(L*SR);t=np.arange(n)/SR;f=p['f0']
    hum=additive([f*k for k in (1,2,3,4,6,8,12)],[1,.6,.35,.3,.14,.1,.05],n,rng,L)*(1+p['wobble']*np.sin(2*np.pi*on_grid(3.,L)*t))
    buzz=additive([f*4+.5,f*4-.5,f*16,f*24],[.25,.25,.08,.05],n,rng,L)
    hiss=band(rng.normal(size=n),2000,11000)
    texture=band(Sources.jet()[5*SR:5*SR+n],60,6000)
    return loop_of(norm(hum,.14)+norm(buzz,.14*p['buzz']+1e-6)+norm(hiss,.1*p['hiss']+1e-6)+norm(texture,.14*p['jet']+1e-6),.16)
def r_air(p,rng,i):
    L=4.;n=int(L*SR);t=np.arange(n)/SR
    rush=band(rng.normal(size=n),p['lo'],p['hi'])+p['bright']*band(rng.normal(size=n),3000,15000)
    whistle=additive([p['whistle_hz'],p['whistle_hz']*1.33],[1,.6],n,rng,L)
    return loop_of(norm(rush,.17)*(1+p['gust']*np.sin(2*np.pi*on_grid(.75,L)*t))+norm(whistle,.17*p['whistle']+1e-6))
def r_boost_loop(p,rng,i):
    # The tuned turbine pushed up in pitch, under a flanged rocket roar.
    L=4.;n=int(L*SR);t=np.arange(n)/SR
    turbine=r_drive({**params()['drive'],'f0':params()['drive']['f0']*p['up']},rng,i)[:n]
    flanged=comb(band(rng.normal(size=n),80,15000),.0035+.0025*np.sin(2*np.pi*on_grid(.5,L)*t),.8)
    texture=band(Sources.jet()[31*SR:31*SR+n],65,12000)
    return loop_of(norm(turbine,.13)+norm(flanged,.13*p['noise']+1e-6)+norm(texture,.13*p['jet']+1e-6))
def r_boost(p,rng,i):
    n=int(p['length']*SR);t=np.arange(n)/SR
    drop=chirp(p['drop_hz'],38,n,.5)*np.exp(-t*5)
    whoosh=lowpass(band(rng.normal(size=n),120,16000),600+14000*np.sin(np.pi*np.minimum(t/p['open'],1)/2)**2)*env(n,.03,p['decay'])
    rise=chirp(180+20*i,p['rise_hz'],n,.7,(1,.5,.33,.25,.2))*env(n,.05,p['decay'])
    texture=fit(band(Sources.jet()[31*SR:33*SR],65,14000),n,1.1)*env(n,.02,p['decay'])
    return norm(drop,.16*p['sub'])+norm(comb(whoosh,.002+.003*t),.2)+norm(rise,.1*p['tone']+1e-6)+norm(texture,.15*p['jet']+1e-6)
def r_launch(p,rng,i):
    n=int(.75*SR);t=np.arange(n)/SR
    ignite=band(rng.normal(size=n),2500,16000)*np.exp(-t*40)
    rocket=lowpass(band(rng.normal(size=n),90,14000),p['bright']*np.exp(-t*p['fall'])+400)*env(n,.01,p['decay'])
    thump=np.sin(2*np.pi*(50*t+30*(1-np.exp(-t*30))/30))*np.exp(-t*14)
    texture=fit(band(Sources.jet()[31*SR:33*SR],65,14000),n,.95+i*.03)*np.exp(-t*p['decay'])
    return norm(ignite,.12*p['ignite']+1e-6)+norm(rocket,.18)+norm(thump,.12*p['thump']+1e-6)+norm(texture,.18*p['jet']+1e-6)
def r_explosion(p,rng,i):
    n=int(1.85*SR);t=np.arange(n)/SR
    kick=np.sin(2*np.pi*(p['kick_hz']*t+40*(1-np.exp(-t*18))/18))*np.exp(-t*4.5)
    body=lowpass(rng.normal(size=n),p['bright']*np.exp(-t*p['fall'])+300)*np.exp(-t*p['decay'])
    debris=crackle(n,rng,900*np.exp(-t*2.8),1800,13000)
    crack=Sources.material('metal',i,n,.7)*np.exp(-t*9)
    return norm(kick,.2*p['kick'])+norm(body,.2)+norm(debris,.2*p['debris']+1e-6)+norm(crack,.2*p['metal']+1e-6)
def r_rail(p,rng,i):
    n=int(.9*SR);t=np.arange(n)/SR
    click=np.zeros(n);click[:24]=np.linspace(1,0,24)
    bolt=chirp(p['bolt_hz']-120*i,p['bolt_end_hz'],n,p['curve'],(1,.6,.4,.25,.15))*np.exp(-t*p['decay'])
    zap=band(rng.normal(size=n),4000,16000)*np.exp(-t*28)
    ring=additive([1210,2930,4710,6990],[1,.6,.4,.2],n,rng)*np.exp(-t*6)
    boom=np.sin(2*np.pi*(55*t+25*(1-np.exp(-t*25))/25))*np.exp(-t*10)
    rail=norm(click,.5)*.3+norm(bolt,.13)+norm(zap,.13*p['zap']+1e-6)+norm(ring,.13*p['ring']+1e-6)+norm(boom,.13*p['boom']+1e-6)
    d=int(.11*SR)
    return rail+p['echo']*np.concatenate([np.zeros(d),rail[:-d]])
def r_sentry(p,rng,i):
    n=SR//2;gun=np.zeros(n)
    for j in range(10):
        m=int(p['bolt']*SR);u=np.arange(m)/SR
        zap=chirp(p['hz']+80*(j%3),p['end_hz'],m,.6,(1,.35,.15))*np.exp(-u*60)+p['body']*np.sin(2*np.pi*170*u)*np.exp(-u*90)
        zap[:48]*=np.linspace(0,1,48)
        start=int(j*.05*SR);gun[(start+np.arange(m))%n]+=zap
    return norm(gun,.12)
def r_emp(p,rng,i):
    n=int(1.1*SR);t=np.arange(n)/SR
    fall=chirp(p['hz'],110,n,.5,(1,.3))*np.exp(-t*3)
    sparks=crackle(n,rng,p['density']*np.exp(-t*2.5),1500,12000)
    field=lowpass(np.sign(np.sin(2*np.pi*118*t))*.5*(1+np.sin(2*np.pi*31*t))*np.exp(-t*4),3500.)
    return norm(fall,.12)+norm(sparks,.12*p['sparks']+1e-6)+norm(field,.12*p['field']+1e-6)+norm(np.sin(2*np.pi*45*t)*np.exp(-t*9),.15*p['thump']+1e-6)
def r_warp(p,rng,i):
    n=int(1.*SR);t=np.arange(n)/SR
    sweep=chirp(p['from_hz'],p['to_hz'],n,p['curve'],(1,.5,.33,.2))*np.sin(np.pi*np.minimum(t/.85,1))
    tunnel=comb(lowpass(band(rng.normal(size=n),150,16000),500+12000*(t/t[-1])**2),.001+.004*(1-t/t[-1]),.8)*np.sin(np.pi*t/t[-1])
    m=int(.85*SR);pop=np.zeros(n);pop[m:]=band(rng.normal(size=n-m),200,15000)*np.exp(-np.arange(n-m)/SR*30)
    texture=fit(band(Sources.jet()[31*SR:33*SR],65,14000),n,1.3)*np.sin(np.pi*t/t[-1])
    return norm(sweep,.1*p['tone']+1e-6)+norm(tunnel,.16)+norm(pop,.1*p['pop']+1e-6)+norm(texture,.16*p['jet']+1e-6)
def r_cue(notes,length):
    def make(p,rng,i):
        n=int(SR*length);x=np.zeros(n);step=n//len(notes) if len(notes)>1 and p.get('arp',1) else 0
        for j,f in enumerate(notes):
            start=j*step;m=n-start
            x[start:]+=lowpass(tone(f*p['pitch'],m,p['detune'],int(p['odd'])),p['cutoff'])*env(m,.004,p['decay']/length)
        return x*.5
    return make
CUE={'pitch':1.,'detune':.004,'odd':5,'cutoff':6000.,'decay':4.5}
RECIPES={
    'drive':(r_drive,dict(f0=45.,roll=.83,f1=667.,f1g=2.65,f2=1500.,f2g=0.,vib=5.9,nlo=40.,nhi=16000.,pulse=.48,sub=.72,whine=.67,noise=.34,jet=1.08),True,['original turbine synthesis','Freesound:152509']),
    'idle':(r_idle,dict(f0=55.,wobble=.18,buzz=.36,hiss=.11,jet=0.),True,['original hover hum synthesis','Freesound:152509']),
    'air':(r_air,dict(lo=300.,hi=15000.,bright=.6,gust=.12,whistle_hz=3900.,whistle=.07),True,['original filtered noise']),
    'boost_loop':(r_boost_loop,dict(up=1.3,noise=.6,jet=.45),True,['original synthesis','Freesound:152509']),
    'boost':(r_boost,dict(length=.9,drop_hz=130.,open=.35,decay=3.2,rise_hz=520.,sub=1.,tone=.7,jet=0.),False,['original synthesis','Freesound:152509']),
    'launch':(r_launch,dict(bright=9000.,fall=3.,decay=3.5,ignite=1.,thump=1.,jet=0.),False,['original synthesis','Freesound:152509']),
    'explosion':(r_explosion,dict(kick_hz=38.,kick=1.,bright=5200.,fall=2.2,decay=3.8,debris=.35,metal=.4),False,['Kenney:impactMetal_heavy','original synthesis']),
    'rail':(r_rail,dict(bolt_hz=3400.,bolt_end_hz=260.,curve=.35,decay=7.,zap=.77,ring=.38,boom=0.,echo=.35),False,['original synthesis']),
    'sentry':(r_sentry,dict(bolt=.045,hz=2600.,end_hz=700.,body=.5),True,['original laser synthesis']),
    'emp':(r_emp,dict(hz=950.,density=2500.,sparks=.83,field=.58,thump=1.),False,['original synthesis']),
    'warp':(r_warp,dict(from_hz=160.,to_hz=2400.,curve=1.6,tone=1.,pop=1.,jet=0.),False,['original synthesis','Freesound:152509']),
    'pickup':(r_cue([1175,1568],.16),dict(CUE),False,['original synthesis']),
    'lap':(r_cue([784,1175],.3),dict(CUE),False,['original synthesis']),
    'finish':(r_cue([523,659,784,1047],.9),dict(CUE,arp=0),False,['original synthesis']),
    'tick':(r_cue([880],.14),dict(CUE),False,['original synthesis']),
    'go':(r_cue([1760,880],.45),dict(CUE,arp=0),False,['original synthesis']),
    'warning':(r_cue([740,554],.36),dict(CUE),False,['original synthesis']),
}
ONE_SHOTS={'boost','launch','explosion','rail','emp','warp','pickup','lap','finish','tick','go','warning'}

def params():
    tuned=json.loads(PARAMS.read_text()) if PARAMS.exists() else {}
    return {name:{**defaults,**tuned.get(name,{})} for name,(_,defaults,_,_) in RECIPES.items()}

def render(name,p,variant=0):
    fn,_,loop,_=RECIPES[name]
    return finish(fn(p,np.random.default_rng(901+variant*131+sum(map(ord,name))),variant),loop)

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    tuned=params()
    for name,(fn,_,loop,sources) in RECIPES.items():
        for i in (range(5) if name in ONE_SHOTS else [None]):
            save(name if i is None else f'{name}_{i+1}',render(name,tuned[name],i or 0),sources,loop)
    # Physical knocks keep the Kenney recordings (now with their full top end).
    rng=np.random.default_rng(602610);n=SR*7;t=np.arange(n)/SR
    save('scrape',seam(norm(band(rng.normal(size=n),700,7000),.15)*(1+.3*np.sin(2*np.pi*37*t))),['original filtered noise'],True)
    for i in range(5):
        n=int(.36*SR);t=np.arange(n)/SR
        save(f'contact_{i+1}',norm(Sources.material('metal',i,n,.82+i*.02),.16)*np.exp(-t*9)+.12*np.sin(2*np.pi*83*t)*np.exp(-t*24),['Kenney:impactMetal_heavy_%03d'%i,'original bass'])
        save(f'land_{i+1}',norm(Sources.material('heavy',i,n,.8),.17)*np.exp(-t*7)+.14*np.sin(2*np.pi*58*t)*np.exp(-t*21),['Kenney:impactPunch_heavy_%03d'%i,'original bass'])
    doc={'version':'spacesynth-2026-10-18','sample_rate':SR,'params':tuned,'source_records':json.loads((SRC/'sources.json').read_text()),'kenney':{'url':'https://kenney.nl/assets/impact-sounds','license':'CC0-1.0','archive_sha256':hashlib.sha256((SRC/'kenney-impact.zip').read_bytes()).hexdigest()},'assets':MANIFEST}
    (OUT/'manifest.json').write_text(json.dumps(doc,indent=2)+'\n',encoding='utf8')
    print('Rendered',len(MANIFEST),'clips; total',round(sum(x['seconds'] for x in MANIFEST),1),'seconds')
if __name__=='__main__':main()
