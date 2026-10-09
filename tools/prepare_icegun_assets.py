"""Preserve Creator Store artwork while removing all legacy gameplay authority.
Run from the repository: python tools/prepare_icegun_assets.py
The two original exports are inputs only; never map them into a live place.
"""
from pathlib import Path
import copy
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "icegun"

def name(item):
    return item.find("Properties/*[@name='Name']").text

def child(item, key):
    return next(i for i in item.findall("Item") if name(i) == key)

def prop(item, tag, key, value):
    p = item.find("Properties")
    old = p.find(f"*[@name='{key}']")
    if old is not None:
        p.remove(old)
    e = ET.SubElement(p, tag, name=key)
    e.text = str(value)
    return e

def new(class_name, key):
    i = ET.Element("Item", attrib={"class": class_name, "referent": "IceGun" + key})
    ET.SubElement(i, "Properties")
    prop(i, "string", "Name", key)
    return i

def vector(item, key, values):
    e = prop(item, "Vector3", key, "")
    for axis, value in zip("XYZ", values):
        ET.SubElement(e, axis).text = str(value)

def content(item, key, url):
    e = prop(item, "Content", key, "")
    ET.SubElement(e, "url").text = url

def inert(item, anchored):
    for key, value in {"Anchored": anchored, "CanCollide": False, "CanTouch": False,
                       "CanQuery": False, "Massless": True}.items():
        prop(item, "bool", key, str(value).lower())

def save(tree, path):
    assert not any(i.get("class") in ("Script", "LocalScript", "ModuleScript", "RemoteEvent", "RemoteFunction")
                   for i in tree.getroot().iter("Item"))
    ET.indent(tree, space="  ")
    tree.write(OUT / path, encoding="utf-8", xml_declaration=True)

def prepare():
    OUT.mkdir(parents=True, exist_ok=True)
    gun_tree = ET.parse(ROOT / "icegun.rbxmx")
    gun = gun_tree.getroot().find("Item")
    main = child(gun, "GunMain")
    bullet = child(main, "BulletScript")
    freeze = child(bullet, "Freeze")
    freeze_source = freeze.find("Properties/*[@name='Source']").text
    effects = new("Folder", "Effects")
    for key in ("SnowBullet", "SnowSplosion", "Shatter"):
        effects.append(copy.deepcopy(child(bullet, key)))
    frost = new("Folder", "FreezeEffects")
    for key in ("IceCrack", "Puff", "Shatter", "FrostSparkles"):
        frost.append(copy.deepcopy(child(freeze, key)))
    effects.append(frost)
    # These Parts were constructed by the original source, rather than exported instances.
    # Retain its exact mesh/texture IDs and visual settings, with inert physics.
    projectile = new("Part", "Projectile")
    inert(projectile, True)
    prop(projectile, "Color3uint8", "Color3uint8", 0xFFFF0000)  # original Really red
    prop(projectile, "token", "Material", 288)  # original Neon
    prop(projectile, "token", "shape", 0)  # original Ball
    vector(projectile, "size", (.4, .4, 2))
    mesh = copy.deepcopy(child(child(child(gun, "Handle"), "Launch"), "Mesh"))
    vector(mesh, "Scale", (1.2, 1.2, 1.2))
    projectile.append(mesh)
    effects.append(projectile)
    ice = new("Part", "IceBlock")
    inert(ice, False)
    vector(ice, "size", (4.2, 4, 6.3))
    prop(ice, "float", "Transparency", .4)
    block_mesh = new("SpecialMesh", "Mesh")
    prop(block_mesh, "token", "MeshType", 5)
    for key in ("MeshId", "TextureId"):
        url = re.search(key+r' = "([^"\n]+)"', freeze_source)
        if not url:
            raise ValueError(f"Missing original ice block {key}")
        content(block_mesh, key, url.group(1))
    vector(block_mesh, "Scale", (1, 1, 1))
    ice.append(block_mesh)
    effects.append(ice)
    for parent in list(gun.iter("Item")):
        for i in list(parent.findall("Item")):
            if i.get("class") in ("Script", "LocalScript", "ModuleScript", "RemoteEvent", "RemoteFunction") or name(i) == "TeamAttack":
                parent.remove(i)
    inert(child(gun, "Handle"), False)
    prop(gun, "bool", "CanBeDropped", "false")
    effect_root = copy.deepcopy(gun_tree.getroot())
    for i in list(effect_root.findall("Item")):
        effect_root.remove(i)
    prop(effects, "string", "Name", "IceGunEffects")
    effect_root.append(effects)
    save(ET.ElementTree(effect_root), "IceGunEffects.rbxmx")
    save(gun_tree, "IcicleGun.rbxmx")
    pedestal_tree = ET.parse(ROOT / "icegunspawner.rbxmx")
    pedestal = pedestal_tree.getroot().find("Item")
    for i in list(pedestal.findall("Item")):
        if i.get("class") == "Script":
            pedestal.remove(i)
        elif i.get("class") == "ManualWeld" and i.find("Properties/*[@name='Part0']").text == "null":
            # The union is independently anchored; its original CFrame is preserved.
            assert pedestal.find("Properties/*[@name='Anchored']").text == "true"
            pedestal.remove(i)
    save(pedestal_tree, "EquipmentSpawner.rbxmx")
    print("Prepared original gun, effects and union; no executable scripts or remotes remain.")

if __name__ == "__main__":
    prepare()
