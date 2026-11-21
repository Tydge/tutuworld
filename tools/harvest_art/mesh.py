"""Small offline indexed-surface writer for the garden and tailor models (NumPy)."""
from collections import defaultdict
from math import cos, sin, tau
from pathlib import Path
import json
import struct

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
UP = np.array([0., 1., 0.])


def vec(x, y, z):
    return np.array([x, y, z], dtype=float)


def unit(v):
    return v / max(np.linalg.norm(v), 1e-10)


def rgb(value):
    return np.array(list(bytes.fromhex(value))) / 255.


def mix(a, b, t):
    return a * (1 - t) + b * t


class Model:
    def __init__(self):
        self.parts = defaultdict(list)
        self.morphs = {}

    def patch(self, material, nu, nv, sample, wrap_u=False, wrap_v=False, flip=False, pigment=None):
        """sample(u,v) returns a position and sRGB paint. Weld periodic seams."""
        nx, ny = nu + int(not wrap_u), nv + int(not wrap_v)
        vertices, colors, indices = [], [], []
        for j in range(ny):
            for i in range(nx):
                p, col = sample(i / nu, j / nv)
                vertices.append(p)
                colors.append(col)
        for j in range(nv):
            for i in range(nu):
                a, b = j * nx + i, j * nx + (i + 1) % nx
                c, d = ((j + 1) % ny) * nx + i, ((j + 1) % ny) * nx + (i + 1) % nx
                indices.extend(((a, c, b), (b, c, d)) if flip else ((a, b, c), (b, d, c)))
        vertices, indices = np.array(vertices), np.array(indices)
        tri = vertices[indices]
        normals = np.zeros_like(vertices)
        face = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
        for corner in range(3):
            np.add.at(normals, indices[:, corner], face)
        normals /= np.maximum(np.linalg.norm(normals, axis=1, keepdims=True), 1e-12)
        uv = np.full((len(vertices), 2), .993)
        if material in ("Cloth","SilkBack"):
            uv = np.array([(i/nu,j/nv) for j in range(ny) for i in range(nx)])
        if pigment:
            origin = dict(blade=(0,0), palm=(.5,0), rind=(0,.5), root=(.5,.5))[pigment]
            uv = np.array([(i/nu,j/nv) for j in range(ny) for i in range(nx)])*.477 + .009 + origin
        self.parts[material].append((vertices, normals, np.clip(colors, 0, 1), indices, uv))

    def tube(self, path, radius, color, sides=6, material='Botanical', closed=False):
        points = np.array(path)
        count = len(points)
        tangent = [unit(points[(i+1) % count if closed else min(i+1, count-1)] -
                        points[(i-1) % count if closed else max(0, i-1)]) for i in range(count)]
        # Parallel transport prevents sudden twists at bends and near-vertical stems.
        right = unit(np.cross(tangent[0], vec(1, 0, 0) if abs(tangent[0][0]) < .8 else UP))
        frames = []
        for axis in tangent:
            right = unit(right - axis * right.dot(axis))
            frames.append((right, np.cross(right, axis)))
        def point(u, v):
            i = round(v * (count if closed else count-1)) % count
            a, b = frames[i]
            radial = a * cos(tau*u) + b * sin(tau*u)
            return points[i] + radial * (radius(v) if callable(radius) else radius), color
        self.patch(material, sides, count if closed else count-1, point, True, closed)


def write_glb(path, models):
    blob = bytearray()
    gltf = dict(asset=dict(version='2.0', generator='Tutu World art tools'), scene=0,
                scenes=[dict(nodes=list(range(len(models))))], nodes=[], meshes=[],
                materials=[], accessors=[], bufferViews=[])
    def accessor(data, dtype, kind, component, bounds=False, normalized=False):
        data = np.ascontiguousarray(data, dtype=dtype)
        blob.extend(bytes((-len(blob)) % 4))
        view = dict(buffer=0, byteOffset=len(blob), byteLength=data.nbytes)
        blob.extend(data.tobytes())
        acc = dict(bufferView=len(gltf['bufferViews']), count=len(data), type=kind, componentType=component)
        if bounds:
            acc.update(min=data.min(axis=0).tolist(), max=data.max(axis=0).tolist())
        if normalized:
            acc['normalized'] = True
        gltf['bufferViews'].append(view)
        gltf['accessors'].append(acc)
        return len(gltf['accessors']) - 1
    roles = {}
    for name, model in models.items():
        primitives = []
        for role, chunks in model.parts.items():
            if role not in roles:
                roles[role] = len(roles)
                gltf['materials'].append(dict(name=role, doubleSided=role=='Botanical',
                    pbrMetallicRoughness=dict(metallicFactor=0., roughnessFactor=.78)))
            offsets = np.cumsum([0] + [len(c[0]) for c in chunks[:-1]])
            pos, norm, color = [np.concatenate([c[k] for c in chunks]) for k in range(3)]
            idx = np.concatenate([c[3]+start for c, start in zip(chunks, offsets)]).ravel()
            attr = dict(POSITION=accessor(pos,'<f4','VEC3',5126,True),
                        NORMAL=accessor(norm,'<f4','VEC3',5126))
            if role in ('Botanical','Cloth','SilkBack'):
                attr['TEXCOORD_0'] = accessor(np.concatenate([c[4] for c in chunks]), '<f4', 'VEC2', 5126)
            if role == 'Botanical':
                # glTF vertex colors are linear. RGBA8 avoids runtime color textures.
                linear = np.where(color <= .04045, color / 12.92, ((color+.055)/1.055)**2.4)
                rgba = np.column_stack((linear, np.ones(len(color))))
                attr['COLOR_0'] = accessor(np.rint(rgba*255),'u1','VEC4',5121,normalized=True)
            primitive = dict(attributes=attr, indices=accessor(idx,'<u2','SCALAR',5123), material=roles[role])
            if model.morphs:
                primitive['targets'] = []
                for deform in model.morphs.values():
                    delta = deform(pos)
                    # Keep authored normals on unmoving pieces. Only the front hem bends.
                    target = dict(POSITION=accessor(delta,'<f4','VEC3',5126,True))
                    primitive['targets'].append(target)
            primitives.append(primitive)
        gltf['nodes'].append(dict(name=name, mesh=len(gltf['meshes'])))
        mesh = dict(name=name, primitives=primitives)
        if model.morphs:
            mesh.update(weights=[0.] * len(model.morphs), extras=dict(targetNames=list(model.morphs)))
        gltf['meshes'].append(mesh)
    blob.extend(bytes((-len(blob)) % 4))
    gltf['buffers'] = [dict(byteLength=len(blob))]
    header = json.dumps(gltf, separators=(',', ':')).encode()
    header += b' ' * ((-len(header)) % 4)
    path.write_bytes(struct.pack('<4sII',b'glTF',2,28+len(header)+len(blob))+
                     struct.pack('<I4s',len(header),b'JSON')+header+
                     struct.pack('<I4s',len(blob),b'BIN\0')+blob)
