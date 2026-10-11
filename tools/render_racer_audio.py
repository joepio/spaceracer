"""Render SpaceRacer's audio. Python + numpy + ffmpeg; no network needed.
Inputs and published CC0 source evidence are in tools/audio_sources.
"""
from pathlib import Path
import hashlib, json, subprocess, wave, zipfile
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'tools/audio_sources'
OUT=ROOT/'assets/audio/racer'
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

def save(name,x,sources,loop=False):
    x=x-np.mean(x)
    if not loop:
        a=min(int(.003*SR),len(x)//4);b=min(int(.06*SR),len(x)//4)
        x[:a]*=np.linspace(0,1,a);x[-b:]*=np.linspace(1,0,b)
    x*=min(1,.82/max(1e-9,np.max(np.abs(x))))
    p=OUT/(name+'.wav')
    with wave.open(str(p),'wb') as w:
        w.setparams((1,2,SR,0,'NONE','not compressed')); w.writeframes((x*32767).astype('<i2').tobytes())
    settings=p.with_suffix('.wav.import')
    if settings.exists():
        settings.write_text(settings.read_text().replace('compress/mode=2','compress/mode=0'),encoding='utf8')
    else:
        settings.write_text('[remap]\nimporter="wav"\ntype="AudioStreamWAV"\n[params]\ncompress/mode=0\n',encoding='utf8')
    MANIFEST.append(dict(file=p.relative_to(ROOT).as_posix(),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),seconds=len(x)/SR,peak=float(np.max(abs(x))),rms=float(np.sqrt(np.mean(x*x))),loop=loop,sources=sources))

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    jet=decode((SRC/'152509.mp3').read_bytes()); mech=decode((SRC/'407540.mp3').read_bytes())
    idle=norm(seam(band(mech,90,1900),.16),.18)
    drive=norm(seam(band(jet[20*SR:27*SR],100,3600)),.23)
    boost=norm(seam(band(jet[31*SR:38*SR],65,4800)),.23)
    save('idle',idle,['Freesound:407540'],True)
    save('drive',drive,['Freesound:152509'],True)
    save('boost_loop',boost,['Freesound:152509'],True)
    rng=np.random.default_rng(602610)
    n=SR*7;t=np.arange(n)/SR
    # Broad filtered air, no pitched oscillator or repeated short hiss.
    air=norm(band(rng.normal(size=n),240,3100),.2)*(1+.10*np.sin(2*np.pi*.7*t))
    save('air',seam(air),['original filtered noise'],True)
    z=zipfile.ZipFile(SRC/'kenney-impact.zip')
    mats={k:[decode(z.read(f'Audio/{v}_{i:03}.ogg')) for i in range(5)] for k,v in [('metal','impactMetal_heavy'),('heavy','impactPunch_heavy'),('bell','impactBell_heavy'),('click','impactGeneric_light')]}
    def material(k,i,n,rate=1):return fit(band(mats[k][i],65,4200),n,rate)
    scrape=norm(band(rng.normal(size=n),700,2900),.15)*(1+.3*np.sin(2*np.pi*37*t))
    save('scrape',seam(scrape),['original filtered noise'],True)
    # Actual repeating sentry cadence is a loop; no 20 Hz stream allocations.
    n=SR//2;gun=np.zeros(n)
    for i in range(10):
        start=int(i*.05*SR);length=int(.12*SR)
        pulse=material('metal',i%5,length,1.35)*np.exp(-np.arange(length)/SR*55)
        pulse[:96]*=np.linspace(0,1,96);pulse[-480:]*=np.linspace(1,0,480)
        np.add.at(gun,(start+np.arange(length))%n,pulse)
    save('sentry',norm(gun,.14),['Kenney:impactMetal_heavy_000..004'],True)
    for i in range(5):
        rng=np.random.default_rng(901+i*131)
        n=int(1.85*SR);t=np.arange(n)/SR
        noise=norm(band(rng.normal(size=n),45,2400),.20)
        crack=norm(material('metal',i,n,.7),.12)
        boom=.19*np.sin(2*np.pi*(46*t+1.3*(1-np.exp(-t*24))))*np.exp(-t*5)
        blast=noise*np.exp(-t*4.8)+crack*np.exp(-t*10)+boom
        save(f'explosion_{i+1}',blast,['Kenney:impactMetal_heavy_%03d'%i,'original noise and bass'])
        n=int(.36*SR);t=np.arange(n)/SR
        hit=norm(material('metal',i,n,.82+i*.02),.16)*np.exp(-t*9)+.12*np.sin(2*np.pi*83*t)*np.exp(-t*24)
        save(f'contact_{i+1}',hit,['Kenney:impactMetal_heavy_%03d'%i,'original bass'])
        land=norm(material('heavy',i,n,.8),.17)*np.exp(-t*7)+.14*np.sin(2*np.pi*58*t)*np.exp(-t*21)
        save(f'land_{i+1}',land,['Kenney:impactPunch_heavy_%03d'%i,'original bass'])
        n=int(.6*SR);t=np.arange(n)/SR
        pressure=fit(boost,n,1.1)*np.sin(np.pi*np.minimum(t/.6,1))**1.5
        save(f'boost_{i+1}',pressure,['Freesound:152509'])
        launch=fit(boost,n,.95+i*.03)*np.exp(-t*5)+fit(hit,n)*.4
        save(f'launch_{i+1}',launch,['Freesound:152509','Kenney:impactMetal_heavy_%03d'%i,'original bass'])
        snap=norm(band(rng.normal(size=n),300,6000),.16)*np.exp(-t*22)
        charge=.16*np.sin(2*np.pi*(130*t+5*(1-np.exp(-t*40))))*np.exp(-t*13)
        save(f'rail_{i+1}',snap+charge+fit(hit,n)*.7,['Kenney:impactMetal_heavy_%03d'%i,'original noise and resonance'])
        emp=norm(band(rng.normal(size=n),160,2400),.16)*np.exp(-t*5)*(1+.45*np.sin(2*np.pi*44*t))
        save(f'emp_{i+1}',emp,['original filtered noise'])
        warp=fit(boost,n,1.3)*np.sin(np.pi*t/.6)+.09*np.sin(2*np.pi*(210*t+85*t*t))*np.sin(np.pi*t/.6)
        save(f'warp_{i+1}',warp,['Freesound:152509','original resonance'])
        # Short, restrained instrument cues; no victory arpeggio for every pickup.
        for name,freq,length in [('pickup',880,.12),('lap',660,.22),('finish',440,.65),('tick',440,.10),('go',880,.22),('warning',510,.18)]:
            n=int(SR*length);u=np.arange(n)/SR
            x=(np.sin(2*np.pi*freq*u)+.12*np.sin(2*np.pi*freq*2*u))*np.exp(-u/(length*.24))*.14
            if name=='finish': x+=.07*np.sin(2*np.pi*660*u)*np.exp(-u*7)
            save(f'{name}_{i+1}',x,['original oscillator and envelope'])
    doc={'version':'turbine-2026-10-06','sample_rate':SR,'source_records':json.loads((SRC/'sources.json').read_text()),'kenney':{'url':'https://kenney.nl/assets/impact-sounds','license':'CC0-1.0','archive_sha256':hashlib.sha256((SRC/'kenney-impact.zip').read_bytes()).hexdigest()},'assets':MANIFEST}
    (OUT/'manifest.json').write_text(json.dumps(doc,indent=2)+'\n',encoding='utf8')
    print('Rendered',len(MANIFEST),'clips; total',round(sum(x['seconds'] for x in MANIFEST),1),'seconds')
if __name__=='__main__':main()
