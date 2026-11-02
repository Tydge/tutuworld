"""Sign, upload immutable artifacts, then atomically promote the reviewed manifest."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--artifacts',type=Path,required=True)
    parser.add_argument('--signing-key',type=Path,required=True)
    parser.add_argument('--ssh-key',type=Path,required=True)
    mode=parser.add_mutually_exclusive_group()
    mode.add_argument('--stage-only',action='store_true')
    mode.add_argument('--promote',action='store_true')
    source=(ROOT/'scripts/services/release.gd').read_text()
    parser.add_argument('--build',type=int,default=int(re.search(r'const BUILD := (\d+)',source).group(1)))
    parser.add_argument('--version',default=re.search(r'const VERSION := "([^"]+)"',source).group(1))
    args=parser.parse_args()
    if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+',args.version) or args.build<1:raise SystemExit('Invalid version')
    base='https://47.119.37.251/tutuworld/'
    names={'pack':'city.pck','macos':'TutuWorld-macOS.zip','windows':'TutuWorld-Windows.zip'}
    for name in names.values():
        if not (args.artifacts/name).is_file():raise SystemExit('Missing artifact: '+name)
    pack=args.artifacts/'city.pck'
    payload={'schema':1,'build':args.build,'version':args.version,'min_launcher':2,'protocol':int(re.search(r'const PROTOCOL := (\d+)',source).group(1)),'notes':'聊天、台阶和座椅更顺手，潘达也能按时回家啦。','pack':{'url':base+f'releases/{args.version}/city.pck','sha256':hashlib.sha256(pack.read_bytes()).hexdigest(),'bytes':pack.stat().st_size},'installers':{platform:base+f'releases/{args.version}/{names[platform]}' for platform in ['macos','windows']}}
    data=json.dumps(payload,ensure_ascii=False,separators=(',',':')).encode()
    with tempfile.TemporaryDirectory() as folder:
        temporary=Path(folder);(temporary/'payload').write_bytes(data)
        subprocess.run(['openssl','dgst','-sha256','-sign',str(args.signing_key),'-out',str(temporary/'signature'),str(temporary/'payload')],check=True)
        manifest=args.artifacts/'manifest.json'
        manifest.write_text(json.dumps({'payload':data.decode(),'signature':base64.b64encode((temporary/'signature').read_bytes()).decode()},ensure_ascii=False,indent=2))
    root='/srv/illuminati/www/tutuworld'
    release=root+'/releases/'+args.version
    staging=root+f'/releases/.staging-{args.version}-{args.build}'
    options=['-i',str(args.ssh_key),'-o','IdentitiesOnly=yes','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes']
    ssh=['ssh',*options,'root@47.119.37.251']
    if not args.promote:
        subprocess.run(ssh+[f'test ! -e {release} && mkdir -p {staging}'],check=True)
        for name in [*names.values(),'manifest.json']:
            local=args.artifacts/name
            subprocess.run(['scp',*options,str(local),f'root@47.119.37.251:{staging}/{name}'],check=True)
            digest=subprocess.check_output(ssh+[f'sha256sum {staging}/{name}'],text=True).split()[0]
            if digest!=hashlib.sha256(local.read_bytes()).hexdigest():raise SystemExit('Remote digest mismatch: '+name)
        subprocess.run(ssh+[f'mv {staging} {release}'],check=True)
    if args.stage_only:
        print('Staged immutable release',args.version);return
    digest=subprocess.check_output(ssh+[f'sha256sum {release}/manifest.json'],text=True).split()[0]
    if digest!=hashlib.sha256(manifest.read_bytes()).hexdigest():raise SystemExit('Staged manifest differs from reviewed release')
    subprocess.run(ssh+[f'cp {release}/manifest.json {root}/manifest.json.part && if test -f {root}/manifest.json; then cp {root}/manifest.json {root}/manifest.previous.json; fi; mv {root}/manifest.json.part {root}/manifest.json'],check=True)
    print('Published',base+'manifest.json')

if __name__=='__main__':main()
