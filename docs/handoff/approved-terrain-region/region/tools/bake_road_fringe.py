from pathlib import Path
import argparse
import hashlib
import json
import cv2
import numpy as np

parser = argparse.ArgumentParser(description="Bake the packed-earth and gravel mask for the exported paving.")
parser.add_argument("directory", type=Path, help="Directory written by export_paving.gd")
here = parser.parse_args().directory
world_min=np.array([-640.,-400.]); size=np.array([1280.,640.]); metres_per_pixel=.25
width,height=np.round(size/metres_per_pixel).astype(int)
output=np.zeros((height,width,3),np.uint8)
counts=json.loads((here/'pavement_counts.json').read_text(encoding='utf8'))
classes=[
    (['asphalt','gravel','edge'],1.95,3.45,.92),
    (['yard'],2.25,3.85,.96),
    (['walk'],1.15,2.15,.75),
    (['sand'],.85,1.85,.72),
    (['dirt'],.70,1.48,.65),
]
def smooth(x):
    x=np.clip(x,0.,1.)
    return x*x*(3.-2.*x)

def noise(x,z,step,seed):
    a=x/step; b=z/step
    xa=np.floor(a).astype(np.int64); za=np.floor(b).astype(np.int64)
    u=smooth(a-xa); v=smooth(b-za)
    def h(ix,iz):
        n=(ix*73856093)^(iz*19349663)^seed
        n=((n^(n>>16))*2246822519)&0xffffffff
        n=((n^(n>>13))*3266489917)&0xffffffff
        return ((n^(n>>16))&65535)/65535.
    return (1-v)*((1-u)*h(xa,za)+u*h(xa+1,za))+v*((1-u)*h(xa,za+1)+u*h(xa+1,za+1))
def pp(points):
    # Pixel centres in CPU and Godot use exactly the same physical footprint.
    return (points-world_min)/metres_per_pixel-.5
def data(n):
    return np.fromfile(here/(n+'.xy'),dtype='<f4').reshape(-1,3,2)
representative={}
for names,tamp,apron,grit in classes:
    mask=np.zeros((height,width),dtype=np.uint8)
    for name in names:
        tri=data(name)
        px=pp(tri)
        assert (px.min(axis=(0,1))>0).all() and (px.max(axis=(0,1))<[width-1,height-1]).all()
        tmp=np.int32(np.rint(px*16))
        for polygon in tmp:
            cv2.fillConvexPoly(mask,polygon,255,shift=4)
        areas=np.abs((tri[:,1,0]-tri[:,0,0])*(tri[:,2,1]-tri[:,0,1])-(tri[:,2,0]-tri[:,0,0])*(tri[:,1,1]-tri[:,0,1]))
        j=np.argmax(areas)
        representative[name]=tri[j].mean(axis=0).astype(float).tolist()
    box=cv2.boundingRect(mask)
    x0=max(0,box[0]-40);z0=max(0,box[1]-40);x1=min(width,box[0]+box[2]+40);z1=min(height,box[1]+box[3]+40)
    dist=cv2.distanceTransform(255-mask[z0:z1,x0:x1],cv2.DIST_L2,cv2.DIST_MASK_PRECISE)*metres_per_pixel
    iz,ix=np.nonzero(dist<7)
    d=np.maximum(0.,dist[iz,ix]-.5*metres_per_pixel)
    ix+=x0; iz+=z0
    x=(ix+.5)*metres_per_pixel+world_min[0]; z=(iz+.5)*metres_per_pixel+world_min[1]
    coarse=noise(x,z,5.9,10847); fine=noise(x,z,.95,1789); mid=noise(x+23.9,z-45,1.9,37195)
    width_var=.62+.62*coarse+.32*fine
    r=1.-smooth(d/(tamp*width_var))
    end=apron*width_var*(.91+.18*mid)
    g=grit*(.4+.6*smooth(d/(.53*width_var)))*(1.-smooth((d-.34*width_var)/(end-.34*width_var)))*(.51+.54*mid+.07*fine)
    output[iz,ix,0]=np.maximum(output[iz,ix,0],np.rint(np.clip(r,0,1)*255).astype('uint8'))
    output[iz,ix,1]=np.maximum(output[iz,ix,1],np.rint(np.clip(g,0,1)*255).astype('uint8'))
target=here/'road_fringe.png'
assert cv2.imwrite(str(target),cv2.cvtColor(output,cv2.COLOR_RGB2BGR),[cv2.IMWRITE_PNG_COMPRESSION,7])
# Confirm the image itself, edge clamp zone, physical road centres, and no axis/sign inversion.
pixel=cv2.cvtColor(cv2.imread(str(target)),cv2.COLOR_BGR2RGB)
assert np.array_equal(pixel,output)
assert not np.any(pixel[:20]) and not np.any(pixel[-20:]) and not np.any(pixel[:,:20]) and not np.any(pixel[:,-20:])
samples={}
for name,xy in representative.items():
    px=np.rint(pp(np.array(xy))).astype(int)
    v=pixel[px[1],px[0],:2]
    assert v[0]>=250,(name,xy,v)
    samples[name]={'world_xz_m':xy,'rg_u8':v.tolist()}
stats={'pavement_triangles':sum(counts.values()),'source_material_triangles':counts,'metres_per_pixel':metres_per_pixel,'world_xz_min_m':world_min.tolist(),'world_xz_size_m':size.tolist(),'image_size_px':[int(width),int(height)],'data_channels':['R=compaction','G=loose aggregate transition'],'bbox_pixels_rg_nonzero':int(np.any(pixel[:,:,:2]>0,axis=2).sum()),'pavement_centre_samples':samples,'sha256':hashlib.sha256(target.read_bytes()).hexdigest()}
(here/'road_fringe_measurement.json').write_text(json.dumps(stats,indent=2),encoding='utf8')
print('road surface samples and border all passed',samples,'file',target.stat().st_size,stats['sha256'])
