#!/usr/bin/env python3
"""Stage local hardware recipes from the retained, checksummed oma_snap packages."""
import hashlib
import pathlib
import shutil
import subprocess
import sys
import tarfile

root = pathlib.Path(__file__).resolve().parents[2]
lab = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else root.parent / 'oma_snap'
out = root / 'build/hp-thinkpad/hardware'
out.mkdir(parents=True, exist_ok=True)
inputs = {
    'hp': lab / 'build/hp-firmware-package/oma-snap-firmware-hp-7700.1-1-any.pkg.tar.xz',
    't14s': lab / 'build/firmware-package/oma-snap-firmware-ubuntu-20260319.217ca6e4-2-any.pkg.tar.xz',
    'npu': lab / 'build/t14s-npu-firmware-package/oma-snap-firmware-t14s-npu-1.0.0.23-1-any.pkg.tar.xz',
    'audio': lab / 'build/hp-audio-package/oma-snap-audio-hp-0.1.0-1-any.pkg.tar.xz',
}
manifest_names = {'hp': 'hp-firmware-package.sha256', 't14s': 'bridge-packages.sha256',
                  'npu': 't14s-npu-firmware-package.sha256', 'audio': 'hp-audio-package.sha256'}
records = []
for key, path in inputs.items():
    digest = hashlib.file_digest(path.open('rb'), 'sha256').hexdigest()
    manifest = lab / 'manifests' / manifest_names[key]
    if not manifest.exists():
        raise SystemExit(f'Missing provenance manifest: {manifest}')
    if digest not in manifest.read_text():
        raise SystemExit(f'Input hash is not in retained manifest: {path}')
    records.append(f'{digest}  {path.name}')

prefix = 'usr/lib/firmware/7.0.0-31-generic/'
for board in ('hp', 't14s'):
    work = out / f'omarchy-hw-{board}-experimental'
    payload = work / 'payload'
    if payload.exists():
        shutil.rmtree(payload)
    payload.mkdir(parents=True, exist_ok=True)
    fw = payload / 'usr/lib/firmware/updates'
    board_path = 'qcom/x1e80100/' + ('hp/elitebook-ultra-g1q/' if board == 'hp' else 'LENOVO/21N1/')
    selected = ('hp',) if board == 'hp' else ('t14s', 'npu')
    for key in selected:
        with tarfile.open(inputs[key]) as archive:
            for member in archive:
                topology_link = (board == 't14s' and member.name == prefix + board_path +
                                 'X1E80100-LENOVO-Thinkpad-T14s-tplg.bin.zst')
                if not member.name.startswith(prefix + board_path) or not (member.isfile() or topology_link):
                    continue
                relative = member.name.removeprefix(prefix)
                target = fw / relative
                data = archive.extractfile(member).read()
                if target.suffix == '.zst':
                    data = subprocess.run(['zstd', '-dc'], input=data, capture_output=True, check=True).stdout
                    target = target.with_suffix('')
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(data)
                if topology_link:
                    alias = fw / 'qcom/x1e80100/X1E80100-LENOVO-Thinkpad-T14s-tplg.bin'
                    alias.parent.mkdir(parents=True, exist_ok=True)
                    alias.write_bytes(data)
    required = ['qcadsp8380.mbn', 'qccdsp8380.mbn', 'adsp_dtbs.elf', 'cdsp_dtbs.elf']
    if board == 't14s':
        required.append('X1E80100-LENOVO-Thinkpad-T14s-tplg.bin')
    missing = [name for name in required if not (fw / board_path / name).is_file()]
    if missing:
        raise SystemExit(f'Missing {board} firmware: {missing}')
    if board == 'hp':
        with tarfile.open(inputs['audio']) as archive:
            name = prefix + 'qcom/x1e80100/X1E80100-HP-ELITEBOOK-ULTRA-G1Q-tplg.bin'
            target = fw / name.removeprefix(prefix)
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(archive.extractfile(name).read())
        if not target.is_file():
            raise SystemExit('Missing HP audio topology')
        ucm = payload / 'usr/share/alsa/ucm2/conf.d/x1e80100'
        ucm.mkdir(parents=True, exist_ok=True)
        hp_ucm = payload / 'usr/share/alsa/ucm2/Qualcomm/x1e80100'
        hp_ucm.mkdir(parents=True, exist_ok=True)
        stock_ucm = pathlib.Path('/usr/share/alsa/ucm2')
        sources = {
            'Qualcomm/x1e80100/LENOVO-T14s.conf': '93a812a711361e7212471ace6ab4c7eb575999fdf1c99ae4809da769fbde3877',
            'Qualcomm/x1e80100/T14s-HiFi.conf': '6f5956f731c02f54345016e4a2a86299e4af87ef6e0748a0d6a1caf8ecdc9f46',
            'codecs/qcom-lpass/va-macro/DMIC1EnableSeq.conf': 'ad638327f00aaff89b6f19ce4151fbf4c345c2d9394088074eda11b106e8f9eb',
        }
        contents = {}
        for name, expected in sources.items():
            data = (stock_ucm / name).read_bytes()
            if hashlib.sha256(data).hexdigest() != expected:
                raise SystemExit(f'Unexpected ALSA UCM source: {name}')
            contents[name] = data.decode()
        def replace_once(data, old, new):
            if data.count(old) != 1:
                raise SystemExit(f'Expected one UCM match: {old}')
            return data.replace(old, new)
        wrapper = replace_once(contents['Qualcomm/x1e80100/LENOVO-T14s.conf'],
                               '/Qualcomm/x1e80100/T14s-HiFi.conf',
                               '/Qualcomm/x1e80100/HP-HiFi.conf')
        hifi = contents['Qualcomm/x1e80100/T14s-HiFi.conf']
        hifi = replace_once(hifi, '/codecs/qcom-lpass/va-macro/DMIC1EnableSeq.conf',
                            '/Qualcomm/x1e80100/HP-DMIC2EnableSeq.conf')
        dmic = replace_once(contents['codecs/qcom-lpass/va-macro/DMIC1EnableSeq.conf'],
                            "name='VA DMIC MUX1' DMIC1", "name='VA DMIC MUX1' DMIC2")
        (hp_ucm / 'HP-ELITEBOOK-ULTRA-G1Q.conf').write_text(wrapper)
        (hp_ucm / 'HP-HiFi.conf').write_text(hifi)
        (hp_ucm / 'HP-DMIC2EnableSeq.conf').write_text(dmic)
        for name in ('HP-HPEliteBookUltraG1q14inchNotebookAIPC-ConfigID-8CBE.conf', 'X1E80100-HP-ELITEBOOK-ULTRA-G1Q.conf'):
            p = ucm / name
            if p.exists() or p.is_symlink(): p.unlink()
            p.symlink_to('../../Qualcomm/x1e80100/HP-ELITEBOOK-ULTRA-G1Q.conf')
    docs = payload / 'usr/share/doc' / work.name
    docs.mkdir(parents=True, exist_ok=True)
    selected_records = [records[list(inputs).index(key)] for key in ((*selected, 'audio') if board == 'hp' else selected)]
    (docs / 'INPUTS.sha256').write_text('\n'.join(selected_records) + '\n')
    (docs / 'FILES.sha256').write_text(''.join(
        f'{hashlib.sha256(path.read_bytes()).hexdigest()}  /{path.relative_to(payload)}\n'
        for path in sorted(fw.rglob('*')) if path.is_file()))
    (docs / 'README').write_text('Local Dragon hardware experiment. Firmware validated on the oma_snap kernel; Dragon physical validation pending. No QNN SDK/runtime is included.\n')
    init = payload / 'etc/mkinitcpio.conf.d'
    init.mkdir(parents=True, exist_ok=True)
    (init / f'{work.name}.conf').write_text('FILES+=(' + ' '.join('/' + str(p.relative_to(payload)) for p in fw.rglob('*') if p.is_file()) + ')\n')
    (work / 'PKGBUILD').write_text(f'''pkgname={work.name}
pkgver={'0.3' if board == 'hp' else '0.2'}
pkgrel=1
pkgdesc='Local HP/ThinkPad Dragon firmware and audio experiment'
arch=('any')
license=('custom')
depends=('linux-firmware-qcom' 'alsa-ucm-conf' 'omarchy-hw-snapdragon-early-experimental')
options=('!strip' '!debug')
package() {{ cp -a "$startdir/payload/." "$pkgdir/"; }}
''')
(out / 'INPUTS.sha256').write_text('\n'.join(records) + '\n')
print(out)
