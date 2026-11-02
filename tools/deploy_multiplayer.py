"""Explicitly prepare/activate the reviewed game service without touching other apps."""
import argparse
import hashlib
import json
from pathlib import Path
import secrets
import subprocess
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[1]
HOST = 'root@47.119.37.251'
PREPARE = r'''
import grp,hashlib,json,os,pwd,shutil,subprocess,tarfile,zipfile
from pathlib import Path
archive=Path(UPLOAD)
if hashlib.sha256(archive.read_bytes()).hexdigest()!=DIGEST:raise SystemExit('Upload digest mismatch')
try:account=pwd.getpwnam('tutuworld')
except KeyError:
 subprocess.run(['useradd','--system','--home-dir','/var/lib/tutuworld','--shell','/usr/sbin/nologin','tutuworld'],check=True)
 account=pwd.getpwnam('tutuworld')
for name in ['/var/lib/tutuworld','/var/lib/tutuworld-staging']:
 p=Path(name);p.mkdir(parents=True,exist_ok=True);p.chmod(0o700);os.chown(p,account.pw_uid,account.pw_gid)
release=Path('/srv/tutuworld/releases/0.3.0');release.mkdir(parents=True,exist_ok=True)
if (release/'released.json').exists():raise SystemExit('Refusing to overwrite a released service')
for unit in ['tutuworld-stage-world','tutuworld-stage-auth']:subprocess.run(['systemctl','stop',unit],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
engine=Path('/srv/tutuworld/engine/4.6.3/godot');engine.parent.mkdir(parents=True,exist_ok=True)
with tarfile.open(archive) as t:
 for name in ['server.pck','auth_service.py','backup.py']:
  member=t.getmember(name)
  with t.extractfile(member) as source,(release/name).open('wb') as target:shutil.copyfileobj(source,target)
  (release/name).chmod(0o644)
 with t.extractfile('engine.zip') as source:
  temporary=engine.parent/'engine.zip';temporary.write_bytes(source.read())
 with zipfile.ZipFile(temporary) as z:engine.write_bytes(z.read('Godot_v4.6.3-stable_linux.x86_64'))
 temporary.unlink();engine.chmod(0o755)
archive.unlink()
subprocess.run([str(engine),'--headless','--version'],check=True)
common=['systemd-run','--collect','--property=User=tutuworld','--property=Group=tutuworld','--setenv=TUTU_STATE_DIR=/var/lib/tutuworld-staging','--setenv=TUTU_AUTH_PORT=18896','--setenv=TUTU_GAME_PORT=18895']
subprocess.run(common+['--unit=tutuworld-stage-auth','/usr/bin/python3',str(release/'auth_service.py')],check=True)
subprocess.run(common+['--unit=tutuworld-stage-world',str(engine),'--headless','--main-pack',str(release/'server.pck'),'--script','res://server/main.gd'],check=True)
print(json.dumps({'prepared':True,'version':'0.3.0','staging_game_port':18895,'staging_auth_port':18896}))
'''
ACTIVATE = r'''
import datetime,json,os,shutil,subprocess
from pathlib import Path
release=Path('/srv/tutuworld/releases/0.3.0')
if not (release/'server.pck').exists():raise SystemExit('Prepare the service first')
root=Path('/srv/tutuworld');link=root/'current.next'
if link.is_symlink():link.unlink()
link.symlink_to(release);os.replace(link,root/'current')
environment='Environment=TUTU_STATE_DIR=/var/lib/tutuworld\nEnvironment=TUTU_AUTH_PORT=18892\nEnvironment=TUTU_GAME_PORT=18891\nEnvironment=TUTU_VERSION=0.3.0\nEnvironment=TUTU_BUILD=3\nEnvironment=TUTU_RELEASE_MANIFEST=/srv/illuminati/www/tutuworld/manifest.json\n'
base='[Service]\nType=simple\nUser=tutuworld\nGroup=tutuworld\nWorkingDirectory=/srv/tutuworld/current\nUMask=0077\n'+environment+'Restart=on-failure\nRestartSec=3\nNoNewPrivileges=true\nPrivateTmp=true\nProtectSystem=strict\nProtectHome=true\nReadWritePaths=/var/lib/tutuworld\n'
units={
 'tutuworld-auth.service':'[Unit]\nDescription=TutuWorld account service\nAfter=network.target\n'+base+'ExecStart=/usr/bin/python3 /srv/tutuworld/current/auth_service.py\nMemoryMax=640M\n[Install]\nWantedBy=multi-user.target\n',
 'tutuworld-world.service':'[Unit]\nDescription=TutuWorld persistent public world\nRequires=tutuworld-auth.service\nAfter=network.target tutuworld-auth.service\n'+base+'ExecStart=/srv/tutuworld/engine/4.6.3/godot --headless --main-pack /srv/tutuworld/current/server.pck --script res://server/main.gd\nMemoryMax=1500M\nTimeoutStopSec=15\n[Install]\nWantedBy=multi-user.target\n',
 'tutuworld-backup.service':'[Unit]\nDescription=TutuWorld private world backup\n[Service]\nType=oneshot\nUMask=0077\nExecStart=/usr/bin/python3 /srv/tutuworld/current/backup.py\n',
 'tutuworld-backup.timer':'[Unit]\nDescription=TutuWorld hourly private backup\n[Timer]\nOnCalendar=hourly\nPersistent=true\n[Install]\nWantedBy=timers.target\n'}
for name,text in units.items():Path('/etc/systemd/system',name).write_text(text.replace('\n','\n'))
vhost=Path('/etc/nginx/sites-available/illuminati-updates')
original=vhost.read_text();snippet=Path('/etc/nginx/snippets/tutuworld.conf')
snippet.parent.mkdir(parents=True,exist_ok=True)
snippet_text="""location = /tutuworld/ws {
 proxy_pass http://127.0.0.1:18891;
 proxy_http_version 1.1;
 proxy_set_header Upgrade $http_upgrade;
 proxy_set_header Connection "upgrade";
 proxy_set_header Host $host;
 proxy_set_header X-Real-IP $remote_addr;
 proxy_read_timeout 75s;
 proxy_send_timeout 75s;
 proxy_buffering off;
}
location = /tutuworld/health {
 proxy_pass http://127.0.0.1:18892/health;
 add_header Cache-Control "no-store";
}
"""
backup=Path('/root/tutuworld-deploy-backups');backup.mkdir(mode=0o700,exist_ok=True)
stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
shutil.copy2(vhost,backup/('nginx-'+stamp))
snippet.write_text(snippet_text)
include='include /etc/nginx/snippets/tutuworld.conf;'
if include not in original:
 marker='listen 443 ssl default_server;'
 if original.count(marker)!=1:raise SystemExit('Unexpected SSL vhost layout')
 vhost.write_text(original.replace(marker,marker+'\n    '+include,1))
validation=subprocess.run(['nginx','-t'],capture_output=True,text=True)
if validation.returncode:
 vhost.write_text(original)
 raise SystemExit(validation.stderr)
subprocess.run(['systemctl','daemon-reload'],check=True)
subprocess.run(['systemctl','enable','--now','tutuworld-auth.service','tutuworld-world.service','tutuworld-backup.timer'],check=True)
subprocess.run(['systemctl','reload','nginx'],check=True)
for name in ['tutuworld-stage-world','tutuworld-stage-auth']:subprocess.run(['systemctl','stop',name],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
(release/'released.json').write_text(json.dumps({'version':'0.3.0','activated_at':datetime.datetime.now(datetime.timezone.utc).isoformat()}))
print(json.dumps({'activated':True,'public_port':443,'internal_ports':[18891,18892],'existing_vhost_preserved':True}))
'''
STATUS = r'''
import json,subprocess,urllib.request
result={}
for port in [18896,18892]:
 try:
  with urllib.request.urlopen('http://127.0.0.1:'+str(port)+'/health',timeout=3) as response:result[str(port)]=json.load(response)
 except Exception as e:result[str(port)]=type(e).__name__
for name in ['tutuworld-stage-world','tutuworld-world','tutuworld-auth']:
 p=subprocess.run(['systemctl','show',name,'--property=ActiveState,SubState,MemoryCurrent,CPUUsageNSec'],capture_output=True,text=True)
 result[name]=p.stdout.strip()
from pathlib import Path
import time
p=Path('/var/lib/tutuworld/world.json')
if p.exists():
 data=json.loads(p.read_text());result['world_clock']={'epoch':data['epoch'],'alignment':data.get('clock_alignment',{}),'phase_error_seconds':(time.time()-data['epoch'])%3600-time.time()%3600}
print(json.dumps(result,ensure_ascii=False,indent=2))
'''
ALIGN = r'''
from pathlib import Path
import json
p=Path('/var/lib/tutuworld/world.json')
if not p.exists():raise SystemExit('Public world not deployed')
data=json.loads(p.read_text())
if data.get('clock_alignment'):print('Clock already aligned; no change')
else:
 Path('/var/lib/tutuworld/align-hour.request').touch()
 print('One-time clock alignment requested')
'''


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['prepare', 'activate', 'status', 'align-clock'])
    parser.add_argument('--ssh-key', required=True, type=Path)
    parser.add_argument('--artifacts', type=Path)
    parser.add_argument('--engine-zip', type=Path)
    args = parser.parse_args()
    ssh = ['ssh', '-i', str(args.ssh_key), '-o', 'IdentitiesOnly=yes', '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes', HOST]

    def remote(code):
        subprocess.run(ssh + ['python3', '-'], input=code, text=True, check=True)

    if args.action == 'prepare':
        if not args.artifacts or not args.engine_zip:
            parser.error('prepare requires --artifacts and --engine-zip')
        with tempfile.TemporaryDirectory(prefix='tutu-deploy-') as folder:
            archive = Path(folder) / 'candidate.tar.gz'
            with tarfile.open(archive, 'w:gz') as tar:
                tar.add(args.artifacts / 'server.pck', arcname='server.pck')
                tar.add(args.engine_zip, arcname='engine.zip')
                for name in ['auth_service.py', 'backup.py']:
                    tar.add(ROOT / 'server' / name, arcname=name)
            digest = hashlib.sha256(archive.read_bytes()).hexdigest()
            destination = '/tmp/tutuworld-' + secrets.token_hex(8) + '.tar.gz'
            scp = ['scp', '-i', str(args.ssh_key), '-o', 'IdentitiesOnly=yes', '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes', str(archive), HOST + ':' + destination]
            subprocess.run(scp, check=True)
            remote('UPLOAD=' + repr(destination) + '\nDIGEST=' + repr(digest) + '\n' + PREPARE)
    elif args.action == 'activate':
        remote(ACTIVATE)
    elif args.action == 'align-clock':
        remote(ALIGN)
    else:
        remote(STATUS)


if __name__ == '__main__':
    main()
