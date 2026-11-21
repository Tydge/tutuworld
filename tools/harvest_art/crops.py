"""Bake the five field crops from cotyledons through harvest. Units are metres."""
from math import cos, exp, pi, sin, tau
from mesh import Model, ROOT, UP, mix, rgb, unit, vec, write_glb

GREEN, YOUNG = rgb('426c40'), rgb('9bbb52')
RIB, STEM = rgb('a3ba64'), rgb('60894c')
SOIL = vec(0, -.008, 0)
PHYLLOTAXIS = 2.399963


def direction(angle):
    return vec(cos(angle), 0, sin(angle))


def leaf(m, base, angle, reach, rise, width, arch, palette, *, ripple=0., teeth=0., tilt=0., grid=(6, 8)):
    """A curved lamina with a sunken midrib, folded sides and a scalloped margin."""
    front, side = direction(angle), direction(angle + pi/2)
    low, light = palette
    def surface(u, t):
        w = 2*u-1
        spread = max(.015, sin(pi*t)**.76) * (1 + teeth*cos(t*tau*3))
        rib = sin(pi*t)
        p = base + front*(reach*t) + side*(w*width*spread + tilt*t*t)
        p = p + UP*(rise*t + arch*rib + width*spread*(.25*abs(w) + ripple*w*w*sin(t*tau*3 + w)))
        # The central rib and secondary chevrons remain readable at small scale.
        vein = max(0., 1.-abs(w)*4.) * (.32+.33*rib)
        paint = mix(low, light, .14+.43*t+.14*abs(w)+vein*.48)
        return p, paint
    # side x (forward + up) points upwards.
    m.patch('Botanical', *grid, surface, pigment='blade')


def shoot(m, length, grass=False):
    for i in range(3 if grass else 2):
        leaf(m, SOIL, .4+i*(2.3 if grass else pi), length*(.65 if grass else 1.),
             length*(1.9 if grass else .70), length*(.13 if grass else .38),
             length*.26, (GREEN,YOUNG), tilt=.018, grid=(4,5))


def bulb(m, p, radii, low, high, lobes=6, groove=.065, shape='round', segments=24):
    def surface(u,v):
        angle, lat = tau*u, (v-.5)*pi
        h, r = sin(lat), max(.007, cos(lat))
        flute = (.5+.5*cos(lobes*angle+.17*h))
        width = r*(1-groove*flute**2) * (1+.15*h if shape=='root' else 1.)
        y = h
        if shape!='root':
            y -= .19*max(0.,h)**7
            y += .075*max(0.,-h)**7
        grain = .04*sin(angle*3+v*4)+.04*sin(v*19+angle*2)
        paint = mix(low,high,min(.98,max(.02,.43+.23*h+.26*(1.-flute)+grain)))
        return p+vec(width*sin(angle), y, width*cos(angle))*radii, paint
    m.patch('Botanical',segments,10,surface,True,pigment='root' if shape=='root' else 'rind')


def carrot(m, s):
    if s==0:
        shoot(m,.094)
        return
    size = [.0,.48,.69,.86,1.][s]
    if s>=2:
        p=vec(0,-.065,0)
        r=vec(.125,.204,.119)*size
        bulb(m,p,r,rgb('b65327'),rgb('ffae48'),9,.045,'root')
        # Broken growth rings sunk along the exposed shoulder.
        for i in range(4):
            h=.055+i*.019
            lat=(h-p[1])/r[1]
            if lat>=.96: continue
            radius=(1-lat*lat)**.5*(1+.15*lat)
            pts=[p+vec(radius*sin(a)*r[0],h-p[1],radius*cos(a)*r[2]) for a in
                 [i*1.8+j*.14 for j in range(4)]]
            m.tube(pts,.003*size,rgb('d37330'),4)
    base=vec(0,max(.0,.204*size-.067) if s>=2 else .005,0)
    for i in range(3+s):
        a=i*PHYLLOTAXIS+.2
        d=direction(a)
        reach=(.22+.07*sin(i))*size
        height=(.40+.10*cos(i*1.3))*size
        def stem(t):
            return base+d*reach*t**1.45+UP*height*(t+.20*sin(pi*t))
        m.tube([stem(t/5) for t in range(6)],lambda t:(.010-.007*t)*size,STEM,5)
        for k in range(1,5):
            t=.16+k*.145
            for sign in [-1,1]:
                span=(.14-.073*t)*size
                leaf(m,stem(t),a+sign*(.90+.20*t),span,span*.53,span*.23,
                     span*.18,(rgb('386f49'),rgb('92b960')),teeth=.44,grid=(2,8))
        leaf(m,stem(.87),a,.043*size,.075*size,.017*size,.01,(GREEN,YOUNG),grid=(2,5))


def lettuce(m,s):
    if s==0:
        shoot(m,.096)
        return
    size=[0,.43,.63,.83,1.][s]
    for i in range(5+2*s):
        tier=i/(4+2*s)
        a=i*PHYLLOTAXIS
        side,front=direction(a+pi/2),direction(a)
        reach=(.32-.25*tier)*size
        width=(.16-.056*tier)*size
        height=(.14+.25*tier)*size
        def surface(u,t):
            w=2*u-1
            edge=abs(w)
            spread=(.025+.975*sin(pi*t*.965)**.61)*width
            r=reach*(sin(t*pi*.65)-.20*tier*t*t)
            frill=(sin(t*14+a)+.6*sin(t*23-w*2+a))*.018*size*edge**2
            p=SOIL+front*(r-.066*size*edge**2*sin(pi*t))+side*w*spread
            p+=UP*(height*t+.06*size*sin(pi*t)+frill+.06*size*edge**2*sin(pi*t))
            # Butterhead hearts are warmer and paler than the spreading guard leaves.
            low=mix(rgb('346747'),rgb('82aa51'),tier)
            light=mix(rgb('9ac761'),rgb('e1dd86'),tier)
            venation = .40*exp(-30*w*w)*(1-.65*t)+.11*max(0.,cos((t-edge*.32)*tau*3))**4
            return p,mix(low,light,min(1.,.46*t+.16*edge+venation))
        m.patch('Botanical',10,13,surface,pigment='blade')


def blossom(m,p,size,a=0.):
    for i in range(5):
        leaf(m,p,a+i*tau/5,size,-size*.22,size*.32,size*.22,
             (rgb('e9a439'),rgb('ffe68a')),grid=(2,3))


def tomato(m,s):
    if s==0:
        shoot(m,.10)
        return
    scale=[0,.40,.65,.85,1.][s]
    def stalk(t):
        return vec(.055*sin(t*5),.89*t,.045*t*t)*scale+SOIL
    m.tube([stalk(i/7) for i in range(8)],lambda t:(.021-.013*t)*scale,STEM,7)
    for i in range(4+s):
        t=.17+i*(.77/(3+s))
        a=i*PHYLLOTAXIS
        front=direction(a)
        start=stalk(t)
        length=(.31+.04*sin(i))*scale
        def branch(f):
            return start+front*length*f+UP*scale*(.10*sin(pi*f)-.055*f)
        m.tube([branch(j/4) for j in range(5)],lambda v:(.010-.006*v)*scale,STEM,5)
        for k in range(2):
            for sign in [-1,1]:
                leaf(m,branch(.22+k*.28),a+sign*1.02,.14*scale,-.037*scale,.043*scale,.035*scale,
                     (rgb('316840'),rgb('92b065')),teeth=.20,tilt=.012*sign*scale,grid=(4,6))
        leaf(m,branch(.76),a,.13*scale,-.045*scale,.049*scale,.02,(GREEN,YOUNG),teeth=.19,grid=(4,6))
    if s<2:return
    for i in range(2):
        a=1.1+i*2.9
        fork=stalk(.50+.32*i)+direction(a)*.18*scale
        m.tube([stalk(.44+.32*i),fork],.012*scale,STEM)
        for j in range(2+i):
            b=a+(j-1)*1.65
            calyx=fork+direction(b)*(.099+.025*j)*scale-UP*(.085+.032*j)*scale
            m.tube([fork,calyx+UP*.035,calyx],.008*scale,STEM,5)
            if s==2 or (i==1 and j==2):
                blossom(m,calyx,.047*scale,b)
                continue
            r=(.106-.012*j)*scale
            green = s==3 and (j+i)%2==0
            low, high = ('688641','c3c76a') if green else (('bc6333','efab54') if s==3 else ('962d27','e75c38'))
            bulb(m,calyx-UP*r*.74,vec(r,r*.90,r),rgb(low),rgb(high),6,.06,segments=18)
            for k in range(5):
                leaf(m,calyx,a+k*tau/5,r*.57,-r*.26,r*.14,r*.065,(GREEN,STEM),grid=(2,3))


def pumpkin(m,s):
    if s==0:
        shoot(m,.13)
        return
    scale=[0,.44,.69,.87,1.][s]
    def vine(t):
        return vec(.44*t-.18,.019+.032*sin(t*pi),.14*sin(t*4))*scale
    m.tube([vine(i/7) for i in range(8)],lambda t:(.023-.012*t)*scale,rgb('789153'),7)
    for i in range(3+s):
        t=i/(3+s)
        a=i*PHYLLOTAXIS+.45
        base=vine(t)+direction(a)*.135*scale+UP*(.16+.065*sin(i*1.4))*scale
        m.tube([vine(t),base],.012*scale,STEM,5)
        # A broad palmate blade, with five lobes and light veins radiating from the petiole.
        front,side=direction(a),direction(a+pi/2)
        length=.235*scale
        def surface(u,v):
            ang=(u-.5)*tau
            outline=(.77+.23*cos(ang*5))*(.75+.25*cos(ang))
            radius=length*v*outline
            p=base+(front*cos(ang)+side*sin(ang))*radius
            p+=UP*(.042*sin(pi*v)-.28*radius+.025*sin(ang*5)*v*v)*scale
            vein=max(0.,cos(ang*5))**15*(1.-v*.5)
            return p,mix(rgb('437449'),rgb('a6b866'),.20+.25*v+.36*vein)
        m.patch('Botanical',35,6,surface,True,pigment='palm')
    end=vine(.90)
    tendril=[end+vec(.13*t,.105*t+.022*sin(t*13),.03*cos(t*13)-.03)*scale for t in [i/17 for i in range(18)]]
    m.tube(tendril,lambda t:(.007-.004*t)*scale,STEM,4)
    if s==2:
        blossom(m,vine(.58)+UP*.12,.085)
    if s>=3:
        r=.28 if s==4 else .16
        p=vec(.045,r*.73,-.17)
        low,high=('b85b28','ffa945') if s==4 else ('6e8443','c6a94e')
        bulb(m,p,vec(r,r*.84,r*.91),rgb(low),rgb(high),10,.16,segments=40)
        stalk=p+UP*r*.69
        m.tube([stalk,stalk+vec(.005,.056,0),stalk+vec(.048,.106,.014),stalk+vec(.067,.113,.019)],
               lambda t:(.047-.023*t)*scale,rgb('817349'),7)
        m.tube([vine(.45),vec(.02,.06,-.34),stalk+vec(.025,.07,.018)],.012*scale,STEM,5)


def wheat(m,s):
    if s==0:
        shoot(m,.081,True)
        return
    scale=[0,.52,.73,.9,1.][s]
    gold=[GREEN,STEM,rgb('86a154'),rgb('bca351'),rgb('d8ad56')][s]
    pale=mix(gold,rgb('ffe0a0'),.54)
    for i in range(3+s):
        a=i*PHYLLOTAXIS
        front=direction(a)
        h=(.54+.14*cos(i*2))*scale
        base=front*.055+SOIL
        def culm(t):
            return base+UP*h*t+front*(.09*t*t*scale)
        m.tube([culm(0),culm(.48),culm(.75),culm(1)],.009*scale,gold,5)
        for j in range(2):
            leaf(m,culm(.26+.31*j),a+j*1.6,.21*scale,.09*scale,.024*scale,.085*scale,
                 (mix(GREEN,gold,.7),pale),grid=(2,6))
        if s<2:continue
        for j in range(5):
            for sign in [-1,1]:
                d=direction(a+.23*j+(.0 if sign==1 else pi))
                p=culm(1)+UP*(j*.040*scale)+front*.012*j
                def kernel(u,t):
                    r=.027*scale*(.02+sin(pi*t)**.78)
                    point=p+d*(.044*scale*t)+UP*(.081*scale*t)
                    point+=d*cos(tau*u)*r+direction(a+.23*j+pi/2)*sin(tau*u)*r*.60*sign
                    return point,mix(gold,pale,.22+.42*t+.23*(.5+.5*cos(tau*u)))
                m.patch('Botanical',6,4,kernel,True,flip=True)
                tip=p+d*(.040*scale)+UP*.077*scale
                m.tube([tip,tip+d*(.043*scale)+UP*.102*scale],lambda t:(.0048-.0038*t)*scale,pale,3)


if __name__=='__main__':
    for species in (carrot,lettuce,tomato,pumpkin,wheat):
        stages={}
        for s in range(5):
            m=Model()
            species(m,s)
            stages['Phase'+str(s)]=m
        write_glb(ROOT/'assets'/'harvest'/(species.__name__+'.glb'),stages)
