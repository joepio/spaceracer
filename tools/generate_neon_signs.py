"""Original two-tone neon artwork, with a small authored stroke alphabet.

RGB stores primary tubes, secondary tubes, and animated accent tubes. No fonts,
external artwork, or runtime text nodes. Run with Pillow; outputs a 4x4 atlas.
"""
from pathlib import Path
from math import sin, cos, pi
from PIL import Image, ImageDraw, ImageFilter, ImageChops

ROOT = Path(__file__).resolve().parents[1]
NAMES = ['RAMEN', 'PULSE', 'ORBIT', 'VOLT', 'LOTUS', 'NOVA', 'BYTE', 'AERO',
         'MISO', 'LUNA', 'HELIX', 'KINETIC', 'O2', 'HORIZON', 'VECTOR', 'METRO']
ASPECTS = [.8, 1.65, 1., .65, 1., .52, 1.5, 1.8, 1.25, .8, .6, 1.8, .7, 1.5, 1., .65]
# Coordinates on a 4x6 stroke grid. Separate paths don't join.
GLYPHS = {
 'A':['06 20 46','14 34'], 'B':['00 06 36 45 44 33 03','33 42 41 30 00'],
 'C':['40 10 01 05 16 46'], 'D':['00 06 26 45 41 20 00'],
 'E':['40 00 06 46','03 33'], 'F':['40 00 06','03 33'],
 'G':['40 10 01 05 16 46 43 23'], 'H':['00 06','40 46','03 43'],
 'I':['00 40','20 26','06 46'], 'J':['00 40 45 36 16 05'],
 'K':['00 06','40 03 46'], 'L':['00 06 46'],
 'M':['06 00 23 40 46'], 'N':['06 00 46 40'],
 'O':['10 30 41 45 36 16 05 01 10'], 'P':['06 00 30 41 42 33 03'],
 'Q':['10 30 41 45 36 16 05 01 10','24 46'], 'R':['06 00 30 41 42 33 03','23 46'],
 'S':['40 10 01 02 13 33 44 45 36 06'], 'T':['00 40','20 26'],
 'U':['00 05 16 36 45 40'], 'V':['00 26 40'],
 'W':['00 16 23 36 40'], 'X':['00 46','40 06'], 'Y':['00 23 40','23 26'],
 'Z':['00 40 06 46'], '2':['00 30 41 42 06 46'], '4':['30 03 43','30 36'],
 '0':['10 30 41 45 36 16 05 01 10','04 40'], '8':['10 30 41 42 33 13 02 01 10','13 04 05 16 36 45 44 33'],
 ' ':[]}

atlas = Image.new('RGB', (2048, 2048))
preview = Image.new('RGB', (2048, 2048), '#080e17')
for k, (name, aspect) in enumerate(zip(NAMES, ASPECTS)):
    w, h = 512, round(512 / aspect)
    masks = [Image.new('L', (w, h)) for _ in range(3)]
    draws = [ImageDraw.Draw(m) for m in masks]
    def line(points, channel=0, width=5):
        draws[channel].line(points, fill=255, width=width, joint='curve')
        r = width / 2
        for x,y in [points[0], points[-1]]: draws[channel].ellipse((x-r,y-r,x+r,y+r), fill=255)
    def ellipse(box, channel=0, width=5): draws[channel].ellipse(box, outline=255, width=width)
    def arc(box, start, end, channel=0, width=5): draws[channel].arc(box,start,end,fill=255,width=width)
    def text(value, x, y, height, channel=0):
        step=height*.83; x-=max(0,len(value)*step-height*.16)*.5
        for letter in value:
            for path in GLYPHS[letter]:
                line([(x+int(p[0])*height/6,y+int(p[1])*height/6) for p in path.split()],channel,max(3,round(height*.065)))
            x+=step
    cx,cy = w*.5,h*.36
    r = min(w*.29,h*.245)
    def poly(points, channel=0, width=5): line([(cx+x*r,cy+y*r) for x,y in points],channel,width)
    # Distinct housings: some signs have an arch, cropped corners, or a marquee.
    if k in [0,5,9,15]:
        draws[1].rounded_rectangle((24,24,w-24,h-24),radius=w*.32,outline=255,width=4)
    elif k in [1,6,8,11,13]:
        line([(26,h*.8),(26,h-22),(w-26,h-22),(w-26,h*.8)],1,4)
    elif k in [3,10,12]:
        line([(30,h*.22),(30,30),(w-30,30)],1,5)
        line([(w-30,h*.78),(w-30,h-30),(30,h-30)],1,5)
    if k == 0: # steaming noodle bowl / chopsticks
        arc((cx-r,cy-r*.35,cx+r,cy+r),0,180,0,7)
        line([(cx-r,cy+r*.33),(cx+r,cy+r*.33)],0,7)
        line([(cx-r*.3,cy+r),(cx+r*.3,cy+r)],1,5)
        for x in [-.5,0,.5]: poly([(x,-.85),(x-.12,-.6),(x+.08,-.35),(x,-.13)],2,5)
        poly([(-.8,-.03),(1.,-.43)],1,4);poly([(-.75,.1),(1.05,-.25)],1,4)
    elif k == 1: # waveform with twin speakers
        poly([(-1.6,0),(-.8,0),(-.55,-.65),(-.25,.75),(0,-1.),(.35,.5),(.65,0),(1.6,0)],0,7)
        for side in [-1,1]: arc((cx+side*r*1.45-r*.3,cy-r*.8,cx+side*r*1.45+r*.3,cy+r*.8),-70,70,2,4)
    elif k == 2: # orbital hotel symbol
        ellipse((cx-r*.65,cy-r*.65,cx+r*.65,cy+r*.65),0,7)
        ellipse((cx-r*1.2,cy-r*.25,cx+r*1.2,cy+r*.25),1,5)
        ellipse((cx+r*.72,cy-r*.68,cx+r*.92,cy-r*.48),2,7)
    elif k == 3:
        poly([(.3,-1.),(-.65,.05),(-.05,.05),(-.35,1.),(.7,-.18),(.1,-.18),(.3,-1.)],0,8)
        for y in [.22,.31,.40]: line([(55,h*y),(80,h*y)],2,4)
    elif k == 4: # five petal lotus
        for angle in [-pi*.65,-pi*.33,0,pi*.33,pi*.65]:
            pts=[]
            for i in range(49):
                t=i*2*pi/48; x=sin(t)*r*.3; y=(cos(t)-1)*r*.64
                pts.append((cx+x*cos(angle)-y*sin(angle),cy+r*.6+x*sin(angle)+y*cos(angle)))
            line(pts,0 if angle==0 else 1,5)
        arc((cx-r,cy, cx+r,cy+r*1.3),0,180,2,4)
    elif k == 5: # vertical hotel marquee
        cy=h*.22
        for i in range(10):
            a=-pi/2+i*pi/5; rr=r if i%2==0 else r*.4
            b=-pi/2+(i+1)*pi/5; ss=r if (i+1)%2==0 else r*.4
            line([(cx+cos(a)*rr,cy+sin(a)*rr),(cx+cos(b)*ss,cy+sin(b)*ss)],1,6)
        for i,ch in enumerate('NOVA'): text(ch,cx,h*(.38+i*.12),h*.085,0)
        name=''
    elif k == 6: # arcade controller
        poly([(-1.2,.65),(-1.35,.2),(-1.,-.6),(1.,-.6),(1.35,.2),(1.2,.65),(.6,.2),(-.6,.2),(-1.2,.65)],0,6)
        poly([(-.8,-.05),(-.3,-.05)],1,6);poly([(-.55,-.3),(-.55,.2)],1,6)
        for x,y in [(.6,-.25),(.85,0)]: ellipse((cx+r*x-6,cy+r*y-6,cx+r*x+6,cy+r*y+6),2,5)
    elif k == 7:
        for i in range(3): poly([(-1.7+i*.3,-.7+i*.28),(0,.6),(1.7-i*.3,-.7+i*.28)],0 if i==0 else 1,6)
        poly([(0,-.8),(0,-.2)],2,6)
    elif k == 8: # sushi roll
        ellipse((cx-r,cy-r*.6,cx+r,cy+r*.6),0,6)
        ellipse((cx-r*.48,cy-r*.28,cx+r*.48,cy+r*.28),1,7)
        arc((cx-r,cy-r*.2,cx+r,cy+r),0,180,0,6)
        poly([(-.6,-.9),(.9,-1.25)],2,5)
    elif k == 9:
        arc((cx-r,cy-r,cx+r,cy+r),55,305,0,8)
        arc((cx-r*.35,cy-r*.95,cx+r*.8,cy+r*.95),75,285,0,6)
        poly([(.7,-.7),(.85,-.45),(1.1,-.3),(.85,-.15),(.7,.1),(.55,-.15),(.3,-.3),(.55,-.45),(.7,-.7)],2,4)
    elif k == 10: # DNA repair clinic
        for side in [-1,1]:
            line([(cx+side*sin(i/60*2*pi)*r*.72,cy-r+i/60*r*2) for i in range(61)],0 if side==1 else 1,6)
        for i in range(1,8):
            y=-1+i*.25;x=sin(i*.25*pi)*r*.72
            line([(cx-x,cy+y*r),(cx+x,cy+y*r)],2,3)
    elif k == 11:
        for i in range(3): poly([(-1.5+i*1.05,-.8),(-.75+i*1.05,0),(-1.5+i*1.05,.8)],i%3,8)
    elif k == 12: # oxygen garden
        poly([(0,.9),(-.65,.3),(-.75,-.25),(-.2,-.85),(.65,-1.),(.75,-.25),(.4,.5),(0,.9)],0,6)
        poly([(-.25,1.15),(.35,-.45)],1,5)
        for x,y in [(-.8,-.85),(1.,.3)]: ellipse((cx+x*r-9,cy+y*r-9,cx+x*r+9,cy+y*r+9),2,4)
    elif k == 13:
        arc((cx-r,cy-r,cx+r,cy+r),180,360,0,7)
        for i in range(4): poly([(-1.6+i*.17,i*.23),(1.6-i*.17,i*.23)],1 if i>0 else 2,5)
    elif k == 14:
        poly([(0,-1.),(1.,0),(0,1.),(-1.,0),(0,-1.)],1,5)
        poly([(-.45,.5),(0,-.65),(.45,.5),(0,.27),(-.45,.5)],0,7)
        for side in [-1,1]: poly([(side*1.15,-.15),(side*1.15,.15)],2,5)
    else:
        draws[0].rounded_rectangle((cx-r*.75,cy-r,cx+r*.75,cy+r*.8),radius=r*.2,outline=255,width=7)
        draws[1].rounded_rectangle((cx-r*.55,cy-r*.72,cx+r*.55,cy+r*.1),radius=8,outline=255,width=5)
        for side in [-1,1]:
            ellipse((cx+side*r*.42-8,cy+r*.46-8,cx+side*r*.42+8,cy+r*.46+8),2,6)
            poly([(side*.45,.8),(side*.75,1.2)],0,5)
    if name:
        height=min(64, h*.19, w/(max(len(name),2)*.85+1.5))
        text(name,cx,h*(.68 if aspect>1.2 else .73),height,0)
        if k in [0,3,9,10,12,15]: text('24H' if k in [0,3,15] else 'OPEN',cx,h*.87,27,1)
    tile=Image.merge('RGB',masks).resize((512,512),Image.Resampling.LANCZOS)
    atlas.paste(tile,((k%4)*512,(k//4)*512))
    # Review sheet with the same two-tone separation as the shader.
    colored=Image.new('RGB',(w,h),'#080e17')
    for mask,tint in zip(masks,[(65,224,255),(255,105,177),(237,252,255)]):
        ink=Image.new('RGB',(w,h),tint)
        colored=ImageChops.add(colored,Image.composite(ink,Image.new('RGB',(w,h)),mask))
        colored=ImageChops.add(colored,Image.composite(ink,Image.new('RGB',(w,h)),mask.filter(ImageFilter.GaussianBlur(7))).point(lambda x:int(x*.38)))
    colored.thumbnail((478,478),Image.Resampling.LANCZOS)
    preview.paste(colored,((k%4)*512+(512-colored.width)//2,(k//4)*512+(512-colored.height)//2))
atlas.save(ROOT/'assets/neon-signs.png')
preview.save(ROOT/'assets/neon-signs-preview.png')
print('Generated 16 original neon signs')
