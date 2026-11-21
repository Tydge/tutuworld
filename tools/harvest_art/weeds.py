"""Two seasonal weed patches for the margins of a cultivated bed."""
from math import cos, pi, sin, tau
from crops import PHYLLOTAXIS, SOIL, UP, direction, leaf
from mesh import Model, ROOT, mix, rgb, vec, write_glb

OLIVE, TIP = rgb('66733e'), rgb('a6a755')
STALK = rgb('88814a')


def plantain(m, base, mature):
    for i in range(9):
        a=i*PHYLLOTAXIS
        length=.16+.059*cos(i)
        front,side=direction(a),direction(a+pi/2)
        def blade(u,t):
            w=2*u-1
            width=.053*(.03+sin(pi*t)**.88)
            rib=cos(w*pi*3)**6
            p=base+front*length*t+side*w*width+UP*(.075*t+.07*sin(pi*t)+.013*w*w)
            return p,mix(OLIVE,TIP,.19+.27*t+.20*rib)
        m.patch('Botanical',10,7,blade,pigment='blade')
    if not mature:return
    for i in range(3):
        a=i*PHYLLOTAXIS
        end=base+direction(a)*(.075+.03*i)+UP*(.24+.028*i)
        m.tube([base,(base+end)*.5+UP*.018,end],.006,STALK,5)
        def spike(u,t):
            ang=tau*u
            r=.016*(.15+.85*sin(pi*t)**.6)*(1+.14*cos(t*tau*6+ang*2))
            return end+vec(r*sin(ang),.13*t,r*cos(ang)),mix(rgb('76703f'),rgb('c7b484'),.28+.34*t+.22*cos(t*tau*6+ang*2))
        m.patch('Botanical',10,14,spike,True)


def purse(m,base,mature):
    for i in range(7):
        leaf(m,base,i*PHYLLOTAXIS,.17+.035*cos(i),.050,.038,.034,(OLIVE,TIP),teeth=.35,grid=(4,8))
    if not mature:return
    peak=base+vec(.038,.41,-.015)
    m.tube([base,base+vec(.006,.20,.015),peak],lambda t:.008-.004*t,STALK,5)
    for i in range(8):
        a=i*PHYLLOTAXIS
        h=.32+i*.080
        p=mix(base,peak,h)
        end=p+direction(a)*.069+UP*.033
        m.tube([p,end],.0035,STALK,4)
        # Notched, heart-shaped seedpods on alternate pedicels.
        d=direction(a+pi/2)
        def pod(u,t):
            w=2*u-1
            return (end+d*w*.036*(.035+.965*t)+UP*(t*(.061-.020*(1-abs(w))**3))
                    +direction(a)*.007*(1-w*w)),mix(OLIVE,TIP,.35+.48*t-.14*abs(w))
        m.patch('Botanical',6,4,pod)
    for i in range(4):
        p=peak+direction(i*1.9)*.019+UP*(i*.007)
        m.tube([peak,p],.003,STALK,4)
        for j in range(4):
            leaf(m,p,i+j*pi/2,.021,.008,.008,.005,(rgb('b6b997'),rgb('eee7cd')),grid=(2,3))


def crabgrass(m,base,mature):
    for i in range(5):
        a=i*PHYLLOTAXIS
        d=direction(a)
        for j in range(2):
            leaf(m,base+d*.025,a+j*.65,.15+.04*j,.11+.035*j,.012,.085,
                 (rgb('546d43'),rgb('a8a85b')),grid=(2,7))
        if not mature or i%2:continue
        tip=base+d*.13+UP*(.22+.015*i)
        m.tube([base,base+d*.085+UP*.078,tip],.005,rgb('987757'),5)
        for j in range(4):
            angle=a+(j-1.5)*.65
            end=tip+direction(angle)*.093+UP*(.08+.015*cos(j))
            m.tube([tip,end],.0035,STALK,4)
            for k in range(4):
                p=mix(tip,end,.2+k*.18)
                leaf(m,p,angle+.40,.027,.019,.006,.004,(rgb('978754'),rgb('b39c69')),grid=(2,3))


def models():
    result={}
    for mature in [False,True]:
        m=Model()
        plantain(m,SOIL+vec(-.73,0,-.03),mature)
        purse(m,SOIL+vec(.05,0,.70),mature)
        crabgrass(m,SOIL+vec(.69,0,-.34),mature)
        result['Seeded' if mature else 'Rosettes']=m
    return result


if __name__=='__main__':
    write_glb(ROOT/'assets/harvest/weeds.glb',models())
