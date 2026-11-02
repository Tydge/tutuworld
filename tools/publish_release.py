"""Sign and publish a reviewed release. Private keys never enter game packages.
Usage: python3 tools/publish_release.py --artifacts DIR --signing-key PATH --ssh-key PATH
Export and verification are separate; this script refuses missing artifacts.
"""
import argparse,base64,hashlib,json,subprocess,tempfile,re
from pathlib import Path

def main():
 p=argparse.ArgumentParser()
 p.add_argument('--artifacts',type=Path,required=True)
 p.add_argument('--signing-key',type=Path,required=True)
 p.add_argument('--ssh-key',type=Path,required=True)
 p.add_argument('--build',type=int,default=3)
 p.add_argument('--version',default='0.3.0')
 args=p.parse_args()
 if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+",args.version) or args.build<1: raise SystemExit("Invalid release version")
 base='https://47.119.37.251/tutuworld/'
 names={'pack':'city.pck','macos':'TutuWorld-macOS.zip','windows':'TutuWorld-Windows.zip'}
 for name in names.values():
  if not (args.artifacts/name).is_file(): raise SystemExit(f'Missing artifact: {name}')
 pack=args.artifacts/names['pack']
 payload={'schema':1,'build':args.build,'version':args.version,'min_launcher':2,'protocol':2,'notes':'公共海岛开放啦，和朋友一起照料菜园、逛岛聊天。','pack':{'url':base+f'releases/{args.version}/city.pck','sha256':hashlib.sha256(pack.read_bytes()).hexdigest(),'bytes':pack.stat().st_size},'installers':{platform:base+f'releases/{args.version}/{names[platform]}' for platform in ['macos','windows']}}
 data=json.dumps(payload,ensure_ascii=False,separators=(',',':')).encode()
 with tempfile.TemporaryDirectory() as temp:
  src=Path(temp)/'payload';sig=Path(temp)/'signature'
  src.write_bytes(data)
  subprocess.run(['openssl','dgst','-sha256','-sign',str(args.signing_key),'-out',str(sig),str(src)],check=True)
  envelope={'payload':data.decode(),'signature':base64.b64encode(sig.read_bytes()).decode()}
  manifest=args.artifacts/'manifest.json'
  manifest.write_text(json.dumps(envelope,ensure_ascii=False,indent=2))
 root='/srv/illuminati/www/tutuworld'
 release=root+f'/releases/{args.version}'
 staging=root+f'/releases/.staging-{args.version}-{args.build}'
 ssh=['ssh','-i',str(args.ssh_key),'-o','IdentitiesOnly=yes','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','root@47.119.37.251']
 # Every release is immutable. Upload all files and verify remote bytes before promotion.
 subprocess.run(ssh+[f'test ! -e {release} && mkdir -p {staging}'],check=True)
 for name in names.values():
  local=args.artifacts/name
  subprocess.run(['scp','-i',str(args.ssh_key),'-o','IdentitiesOnly=yes','-o','BatchMode=yes',str(local),f'root@47.119.37.251:{staging}/{name}'],check=True)
  actual=subprocess.check_output(ssh+[f'sha256sum {staging}/{name}'],text=True).split()[0]
  if actual!=hashlib.sha256(local.read_bytes()).hexdigest(): raise SystemExit('Remote digest mismatch: '+name)
 subprocess.run(ssh+[f'mv {staging} {release}'],check=True)
 subprocess.run(['scp','-i',str(args.ssh_key),'-o','IdentitiesOnly=yes','-o','BatchMode=yes',str(manifest),f'root@47.119.37.251:{root}/manifest.json.part'],check=True)
 subprocess.run(ssh+[f'if test -f {root}/manifest.json; then cp {root}/manifest.json {root}/manifest.previous.json; fi; mv {root}/manifest.json.part {root}/manifest.json'],check=True)
 print('Published',base+'manifest.json')
if __name__=='__main__': main()
