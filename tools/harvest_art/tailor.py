"""Tailor closed surfaces in the local space of each species' animated fitting anchors."""
from math import asin, cos, exp, pi, sin, sqrt, tau
import re

import numpy as np

from mesh import Model, ROOT, UP, mix, unit, vec, write_glb

WHITE = vec(1,1,1)
CLOTH, BAND, EDGE, HARDWARE = 'Cloth','Ribbon','Binding','Brass'


def profile(m, role, rows, point, n=40):
    def sample(u,v):
        row=rows[round(v*(len(rows)-1))]
        return point(tau*u, *row), WHITE
    m.patch(role,n,len(rows)-1,sample,True)


def ellipse(a, y, x, z):
    return vec(x*sin(a),y,z*cos(a))


def ball(m,role,p,size):
    def shape(u,v):
        a,b=tau*u,(v-.5)*pi
        return p+vec(sin(a)*cos(b),sin(b),cos(a)*cos(b))*size, WHITE
    m.patch(role,12,8,shape,True)


def braid(m,role,pts,radius,closed=False):
    m.tube(pts,radius,WHITE,6,role,closed)


def hats(kind):
    m=Model()
    western=kind=='cowboy_hat'
    # Perched towards the forehead. The brim sweeps forward in each ear sector.
    def brim(a,t,thickness):
        s,c=sin(a),cos(a)
        x=mix(.214,.600 if western else .49,t)*s
        z=mix(.179,.427 if western else .342,t)*c
        if c<0:
            z+=t*.249*(-c)*min(1.,(abs(s)/.62)**2)
        y=.008-.068*t+.16*t*t*abs(s)**4 if western else .008-.047*t+.069*t*t*abs(s)**4
        return vec(x,y+thickness,z)
    # Both sides of the brim plus a narrow corded welt around its edge.
    rows=[(.01,-.017),(.55,-.017),(1.,-.017),(1.,.0),(.70,.0),(.32,.0),(.01,.0)]
    profile(m,CLOTH,rows,brim,64)
    braid(m,EDGE,[brim(tau*i/96,1,-.008) for i in range(96)],.009,True)
    if western:
        # A low cattleman's crease between two longitudinal ridges, pinched at the nose.
        def crown(a,y,rx,rz,crease):
            s,c=sin(a),cos(a)
            dent=.21*max(0.,c)*abs(s)*min(y/.23,1.)
            return vec(rx*s*(1-dent),y-crease*exp(-((rx*s)/.092)**2),rz*c)
        rows=[(-.019,.292,.248,0),(.045,.297,.248,0),(.13,.28,.234,0),
              (.231,.257,.215,.010),(.282,.211,.181,.034),(.30,.152,.135,.055),
              (.298,.081,.081,.073),(.285,.001,.001,.074)]
    else:
        def crown(a,y,rx,rz,crease):
            return ellipse(a,y,rx,rz)
        rows=[(-.018,.272,.23,0),(.035,.268,.227,0),(.13,.242,.209,0),
              (.28,.245,.214,0),(.389,.269,.235,0),(.414,.266,.233,0),
              (.429,.252,.219,0),(.434,.16,.14,0),(.434,.001,.001,0)]
    profile(m,CLOTH,rows,crown,48)
    profile(m,BAND,[(-.095,.192,.151),(-.032,.249,.20),(.008,.27,.222)],ellipse)
    base_x,base_z=(.299,.254) if western else (.273,.234)
    band_top=.081 if western else .102
    rows=[(.020,base_x,base_z),(band_top,base_x-.008,base_z-.005)]
    profile(m,BAND,rows,ellipse)
    for y,rx,rz in rows:
        braid(m,EDGE,[ellipse(tau*i/64,y,rx,rz) for i in range(64)],.004,True)
    if western:
        # Bevelled turquoise cabochon in an antique brass setting.
        ball(m,HARDWARE,vec(0,.050,.253),vec(.052,.043,.012))
        ball(m,'Turquoise',vec(0,.051,.265),vec(.033,.028,.009))
    else:
        # Folded band bow at the side, where it is visible in three-quarter view.
        for sign in [-1,1]:
            ball(m,BAND,vec(-.268,.063,sign*.048),vec(.022,.044,.064))
        ball(m,EDGE,vec(-.284,.063,0),vec(.017,.035,.018))
    return m


def measurements(species):
    source=(ROOT/'scripts/characters/rig_profile.gd').read_text()
    source+='\n'+(ROOT/'config/animals'/(species+'.tres')).read_text()
    def field(name):
        pat=r'(?m)^(?:@export var )?'+name+r'\s*:?=\s*Vector[23]\(([^)]+)'
        return [float(n) for n in re.findall(pat,source)[-1].split(',')]
    return field('body_radii'),field('body_center')[1],field('neck_center'),field('neck_radii')


def shell_point(r, h, a, dress):
    """h is the height relative to the torso equator in body radii."""
    rx,ry,rz=r
    base=sqrt(max(.02,1-h*h))
    rx,rz=rx*base+.043,rz*base+.042
    flare=max(0.,(-h-.02)/.87) if dress else 0.
    if dress:
        drape=1.+.27*flare
        pleat=(.5+.5*cos(12*a+.3*sin(a))) * .044*flare
        rx=max(rx,r[0]*drape+.02)+pleat if h<-.02 else rx
        rz=max(rz,r[2]*drape+.025)+pleat if h<-.02 else rz
    return ellipse(a,h*ry+.008*flare*cos(12*a),rx,rz)


def bodice(r,dress):
    m=Model()
    low=-.91 if dress else -.70
    def ring(role,heights,offset=0):
        def vertex(a,h):
            p=shell_point(r,h,a,dress)
            return p+vec(sin(a)*offset,0,cos(a)*offset)
        profile(m,role,[(v,) for v in heights],vertex,60)
    ring(CLOTH,[low,low+.045,-.57,-.39,-.23,-.11,-.02,.12,.28,.44,.59,.72,.83,.91,.955])
    ring(EDGE,[low-.020,low+.015],.002)
    if dress:
        ring(BAND,[-.04,.075],.008)
        ring(EDGE,[-.044,-.029],.011)
        # The flat sash knot and two folded tails sit above the tail root.
        p=shell_point(r,.028,pi,True)
        for sign in [-1,1]:
            ball(m,BAND,p+vec(sign*.062,0,-.017),vec(.072,.044,.032))
        ball(m,HARDWARE,p+vec(0,0,-.043),vec(.026,.030,.012))
    def front(x,h,pad):
        edge=shell_point(r,h,pi/2,dress)[0]
        a=asin(max(-.95,min(.95,x/edge)))
        p=shell_point(r,h,a,dress)
        return vec(x,p[1],p[2]+pad)
    # Collar rolls under the chin and turns down into two distinct pointed leaves.
    for sign in [-1,1]:
        def collar(u,t):
            x=sign*r[0]*mix(.045+.63*u, .32+.54*u,t)
            h=mix(.90-.09*(1-u),.32+.40*abs(2*u-1)**1.5,t)
            return front(x,h,.009+.018*sin(pi*t)),WHITE
        m.patch('Collar',8,5,collar,flip=(sign==1))
    if not dress:
        def placket(u,t):
            return front((2*u-1)*.027,mix(-.68,.82,t),.007),WHITE
        m.patch(BAND,2,18,placket)
        for h in [-.50,-.19,.12,.42,.71]:
            p=front(0,h,.016)
            ball(m,'Pearl',p,vec(.018,.018,.008))
            braid(m,BAND,[p+vec(-.006,-.005,.009),p+vec(.006,.005,.009)],.0025)
        def pocket(u,t):
            x=r[0]*(.30+.42*u)
            h=mix(.38,-.04+.095*abs(2*u-1),t)
            return front(x,h,.012),WHITE
        m.patch(CLOTH,6,5,pocket,flip=True)
        pts=[pocket(i/8,0)[0]+vec(0,0,.003) for i in range(9)]
        braid(m,EDGE,pts,.005)
    if dress:
        def lift(points, sign):
            # Raise the front panel over the advancing thigh; leave the waistband and back still.
            x,y,z = points.T
            hem = np.clip((-y/r[1]-.08)/.80,0,1)**1.3
            front = np.clip((z/r[2]+.22)/.95,0,1)
            side = np.clip(.5+sign*x/(.52*r[0]),0,1)
            w = hem*front*side
            return np.column_stack((x*.025*w, (.25*r[1]+.067)*w, (.11+r[2]*.18)*w))
        m.morphs = {'LeftStep':lambda p:lift(p,-1),'RightStep':lambda p:lift(p,1)}
    return m


def sleeve(species, dress, sign):
    m=Model()
    radius={'bunny':.104,'panda':.118,'cat_teacher':.115}[species]+.039
    axis=unit(vec(sign*(.075 if species=='bunny' else .045),-.51,.025))
    across=unit(vec(1,0,0)-axis*axis[0])
    fwd=unit(np.cross(axis,across))
    length=.145 if dress else .211
    def ring(a,y,scale):
        return -axis*y+(across*sin(a)+fwd*cos(a))*radius*scale
    rows=[(-length,.91),(-length+.018,.98),(-.082,1.11 if dress else 1.),
          (-.026,1.04),(.031,.98),(.068,.84),(.098,.60),(.116,.23),(.118,.008)]
    profile(m,CLOTH,rows,ring,24)
    profile(m,BAND,[(-length-.006,.92),(-length+.021,.998)],ring,24)
    return m


def neckwear(species,chain):
    r,body_y,neck,nr=measurements(species)
    m=Model()
    # Solve the ring at the intersection of the lower jaw and the dressed torso.
    # CatSurface has a lower, fuller chin than its original collision ellipsoid.
    skull_y, head_x, head_y, head_z, center_z = {
        'bunny': (1.78,.84,.76,.79,0.),
        'cat_teacher': (1.647,.78,.619,.622,.02),
        'panda': (1.74,.73,.61,.66,0.),
    }[species]
    def line(a):
        c=cos(a)
        low,high=body_y,body_y+r[1]*.98
        for _ in range(16):
            y=(low+high)*.5
            surface=shell_point(r,(y-body_y)/r[1],a,False)
            jaw=skull_y-head_y*sqrt(max(.01,1-(surface[0]/head_x)**2-((surface[2]-center_z)/head_z)**2))
            if y<jaw: low=y
            else: high=y
        y=(low+high)*.5-.010
        if chain:
            y-=.053*((1+c)/2)**1.7
        padding=.016 if chain else .012
        p=shell_point(r,(y-body_y)/r[1],a,False)
        return vec(p[0]+sin(a)*padding,y-neck[1],p[2]-neck[2]+c*padding)
    if chain:
        # Even arc-length spacing keeps successive oval links interlocked at the sides.
        samples=[line(i*tau/256) for i in range(257)]
        dist=np.cumsum([0.]+[float(np.linalg.norm(b-a)) for a,b in zip(samples,samples[1:])])
        count=2*round(dist[-1]/.076/2)
        pitch=dist[-1]/count
        for i in range(count):
            a=float(np.interp(i*pitch,dist,np.linspace(0,tau,len(dist))))
            p=line(a)
            tangent=unit(line(a+.003)-line(a-.003))
            outward=unit(np.cross(tangent,UP))
            vertical=unit(np.cross(outward,tangent))
            across=unit(vertical*.72+outward*(.72 if i%2 else -.72))
            def link(u,v):
                ang=tau*u
                center=p+tangent*(pitch*.70*cos(ang))+across*(.034*sin(ang))
                normal=unit(tangent*(cos(ang)*.034)+across*(sin(ang)*pitch*.70))
                cross=unit(np.cross(tangent,across))
                return center+.012*(normal*cos(tau*v)+cross*sin(tau*v)), WHITE
            m.patch('Chain',16,7,link,True,True)
    else:
        def ribbon(a,dy,extra):
            return line(a)+vec(extra*sin(a),dy,extra*cos(a))
        profile(m,BAND,[(-.028,0),(-.025,.007),(.024,.007),(.028,0)],ribbon)
        center=line(0)+vec(0,.001,.035)
        width=r[0]*1.47
        half_knot=width*.063
        knot_height=width*.079
        for sign in [-1,1]:
            def wing(u,v,back=False):
                # A continuous butterfly outline, gathered into two folds at the knot.
                # The outer edge bows out midway between its softly rounded corners.
                flare=sin(pi*u*.52)**.82
                half_height=width*(.052+.188*flare)
                x=half_knot*.74+width*.446*u-width*.044*abs(v)**3*u**2
                y=v*half_height+sign*width*.018*u*u
                folds=(.072*exp(-((v-.64+.13*u)/.34)**2)
                       +.089*exp(-((v+.52-.10*u)/.39)**2)
                       -.048*exp(-((v-.13)/.20)**2))
                fullness=sin(pi*(.07+.84*u))**.76
                z=width*(.045+fullness*folds-.090*u*u+.047*v*flare)
                if back:
                    z-=width*(.016+.080*(1-v*v)*sin(pi*u)**.75)
                return center+vec(sign*x,y,z)
            for back in [False,True]:
                def sheet(u,t):
                    return wing(u,2*t-1,back),WHITE
                m.patch('SilkBack' if back else CLOTH,28,24,sheet,flip=(sign<0)!=back)
            # The fabric turns back on itself at the outer edge. Close the hem
            # as a narrow rolled surface rather than drawing an outline over it.
            for edge in ['upper','lower','end','root']:
                def hem(u,t):
                    if edge in ['upper','lower']:
                        along,v=u,(1 if edge=='upper' else -1)
                    else:
                        along,v=(1 if edge=='end' else 0),2*u-1
                    front=wing(along,v)
                    rear=wing(along,v,True)
                    return mix(front,rear,t),WHITE
                m.patch('SilkBack',24,1,hem,flip=(edge in ['lower','end'])!=(sign<0))
        # A folded strip wraps the centre. Its face is gently squared and its
        # two rolled selvedges pick up narrower highlights than the wings.
        def knot(u,t):
            angle=tau*u
            x=(2*t-1)*half_knot
            lip=.075*exp(-((abs(2*t-1)-.84)/.115)**2)
            sy,sz=sin(angle),cos(angle)
            y=knot_height*(1+lip)*np.sign(sy)*abs(sy)**.63
            z=width*.072*(1+lip)*np.sign(sz)*abs(sz)**.52
            return center+vec(x+.075*y,y,z+width*.035),WHITE
        m.patch(CLOTH,40,14,knot,True,flip=True)
    return m


if __name__=='__main__':
    write_glb(ROOT/'assets/tailoring/millinery.glb',{kind:hats(kind) for kind in ['cowboy_hat','top_hat']})
    for species in ['bunny','cat_teacher','panda']:
        r,_,_,_=measurements(species)
        pieces={}
        for style in ['day_dress','oxford_shirt']:
            dress=style=='day_dress'
            pieces[style]=bodice(r,dress)
            pieces[style+'_left']=sleeve(species,dress,-1)
            pieces[style+'_right']=sleeve(species,dress,1)
        pieces['silk_bowtie']=neckwear(species,False)
        pieces['gold_chain']=neckwear(species,True)
        write_glb(ROOT/'assets/tailoring'/(species+'.glb'),pieces)
