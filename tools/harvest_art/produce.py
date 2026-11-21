"""Build the isolated harvested specimens used to photograph the inventory icons."""
from math import cos, pi, sin, tau
from pathlib import Path
import sys

import numpy as np
from crops import GREEN, STEM, UP, bulb, carrot, direction, leaf, lettuce, pumpkin, wheat
from mesh import Model, mix, rgb, vec, write_glb


def specimens(path):
    models={}
    m=Model()
    carrot(m,4)
    # Replace the buried field root with the complete lifted root and a tapered tip.
    m.parts['Botanical']=m.parts['Botanical'][5:]
    def taproot(u,t):
        a=tau*u
        r=(.010+.14*sin(min(1.,t*1.45)*pi*.52)**.88)*max(.012,1-max(0.,(t-.78)/.22)**2)**.51
        center=vec(.045*(1-t)**2,-.53+.675*t,-.028*(1-t))
        return center+vec(r*sin(a),0,r*cos(a)),mix(rgb('c96329'),rgb('ffa451'),.42+.26*cos(2*a)+.1*t)
    m.patch('Botanical',26,26,taproot,True,pigment='root')
    models['carrot']=m
    m=Model()
    lettuce(m,4)
    models['lettuce']=m
    m=Model()
    for i in range(2):
        r=.26 if i==0 else .19
        p=vec(i*.28,i*.12,-i*.13)
        bulb(m,p,vec(r,.88*r,r),rgb('a22f27'),rgb('f26a43'),6,.078,segments=30)
        calyx=p+UP*.725*r
        for k in range(5):
            leaf(m,calyx,k*tau/5+.6,.65*r,-.18*r,.16*r,.07*r,(GREEN,STEM),grid=(4,6))
        m.tube([calyx,calyx+vec(.012,.06,0),calyx+vec(.05,.092,.02)],.013,STEM)
    models['tomato']=m
    m=Model()
    pumpkin(m,4)
    # Photograph the picked fruit with the cork stem, a cut petiole and a single leaf.
    m.parts['Botanical']=m.parts['Botanical'][-3:-1]
    leaf(m,vec(.11,.44,-.15),-.12,.22,-.055,.085,.032,(GREEN,STEM),teeth=.2)
    models['pumpkin']=m
    m=Model()
    wheat(m,4)
    # Fan three ears into a compact sheaf; the wrapping crosses the stems below the heads.
    parts=m.parts['Botanical']
    per_stem=len(parts)//7
    m.parts['Botanical']=parts[:3*per_stem]
    for i,(p,n,c,idx,uv) in enumerate(m.parts['Botanical']):
        j=i//per_stem
        a=(-.23+j*.23)
        transform=np.array([[cos(a),-sin(a),0],[sin(a),cos(a),0],[0,0,1]])
        m.parts['Botanical'][i]=(p@transform.T,n@transform.T,c,idx,uv)
    for j in range(2):
        m.tube([vec(.082*cos(tau*i/16),.27+j*.018,.065*sin(tau*i/16)) for i in range(16)],.013,rgb('a66a42'),6,closed=True)
    models['wheat']=m
    write_glb(path,models)


if __name__=='__main__':
    specimens(Path(sys.argv[1]))
