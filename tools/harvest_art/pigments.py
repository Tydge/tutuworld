"""Bake one mipmapped pigment atlas. UV islands have gutters to suppress colour bleed."""
import struct
import zlib

import numpy as np
from mesh import ROOT


def make():
    t, u = np.mgrid[0:256, 0:256]/255.
    x = 2*u-1
    rng = np.random.default_rng(12053)
    grain = rng.uniform(-.017,.017,x.shape)
    def line(d,width):
        return np.exp(-(d/width)**2)
    def channels(value,warmth=0.):
        return np.clip(np.stack([value+warmth,value,value-warmth],axis=-1),0,1)
    # Pinnate veins run from the midrib towards the serrated leaf edge.
    branches=t-.28*abs(x)**.77-.022*np.sin(3*np.pi*x)
    rib=line(x,.020+.020*(1-t))
    vein=line(np.sin(branches*5*np.pi),.117)*(1-.70*abs(x))*(1-rib)
    tiny=line(np.sin((branches-.05*abs(x))*14*np.pi),.19)*.024
    leaf=channels(.78+.07*t+.045*abs(x)+.13*rib+.095*vein+tiny+grain,.006)
    # Palmate veins fork towards each of the five points of the squash leaf.
    ang=(u-.5)*2*np.pi
    main=line(np.sin(ang*2.5),.077/np.maximum(t,.22))
    lateral=line(np.sin((t-.17*np.cos(ang*5))*5*np.pi),.15)
    palm=channels(.77+.085*t+.14*main+.06*lateral+grain,.014)
    # Subtle waxy flecks around the shoulder and longitudinal skin striations.
    stripe=np.cos(ang*10+.4*np.sin(np.pi*t))
    pores=rng.random(x.shape)>.984
    rind=channels(.91+.033*stripe+.012*np.cos(ang*22+3*t)+grain+.04*pores,.012)
    # Carrot roots have short, horizontal lenticels with a lighter lip.
    bark=.94+.014*np.sin(ang*17)+grain
    for _ in range(46):
        a,b=rng.random(2)
        rx,ry=rng.uniform(.009,.057),rng.uniform(.0016,.0052)
        bend=b+.006*np.sin((u-a)/rx)
        scar=np.exp(-((u-a)/rx)**4)
        bark+=scar*(.07*line(t-bend+.006,.0026)-.22*line(t-bend,ry))
    root=channels(bark,.009)
    atlas=np.rint(np.concatenate([np.concatenate([leaf,palm],axis=1),np.concatenate([rind,root],axis=1)])*255).astype('u1')
    atlas[-8:,-8:]=255
    raw=b''.join(b'\0'+row.tobytes() for row in atlas)
    def chunk(name,data):
        return struct.pack('>I',len(data))+name+data+struct.pack('>I',zlib.crc32(name+data))
    png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',512,512,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b'')
    (ROOT/'assets/harvest/pigment.png').write_bytes(png)


if __name__=='__main__':
    make()
