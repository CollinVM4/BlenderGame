"""Artwork preservation and legacy authority removal, independent of gameplay tests."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("prepare", ROOT / "tools/prepare_icegun_assets.py")
prepare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prepare)

def canonical(element):
    return (element.tag, sorted(element.attrib.items()), (element.text or "").strip(),
            [canonical(child) for child in element])

class Assets(unittest.TestCase):
    def test_original_artwork_and_safe_outputs(self):
        with tempfile.TemporaryDirectory() as directory:
            prepare.OUT = Path(directory)
            prepare.prepare()
            outputs = {path.name: path.read_bytes() for path in prepare.OUT.glob("*.rbxmx")}
            prepare.prepare()
            self.assertEqual(outputs, {path.name: path.read_bytes() for path in prepare.OUT.glob("*.rbxmx")})
            original_gun = ET.parse(ROOT / "icegun.rbxmx").getroot().find("Item")
            original_pad = ET.parse(ROOT / "icegunspawner.rbxmx").getroot().find("Item")
            gun = ET.parse(prepare.OUT / "IcicleGun.rbxmx").getroot().find("Item")
            pad = ET.parse(prepare.OUT / "EquipmentSpawner.rbxmx").getroot().find("Item")
            effects = ET.parse(prepare.OUT / "IceGunEffects.rbxmx").getroot().find("Item")
            for source, output in ((original_pad, pad), (prepare.child(original_pad, "PointLight"), prepare.child(pad, "PointLight"))):
                self.assertEqual(canonical(source.find("Properties")), canonical(output.find("Properties")))
            for name in ("Mesh", "Launch", "GunBarrel"):
                self.assertEqual(canonical(prepare.child(prepare.child(original_gun, "Handle"), name)),
                                 canonical(prepare.child(prepare.child(gun, "Handle"), name)))
            self.assertEqual(gun.find("Properties/*[@name='CanBeDropped']").text, "false")
            self.assertEqual(prepare.child(gun, "Handle").find("Properties/*[@name='Anchored']").text, "false")
            original_bullet = prepare.child(prepare.child(original_gun, "GunMain"), "BulletScript")
            for name in ("SnowBullet", "SnowSplosion", "Shatter"):
                self.assertEqual(canonical(prepare.child(original_bullet, name)), canonical(prepare.child(effects, name)))
            original_freeze = prepare.child(original_bullet, "Freeze")
            for name in ("Puff", "FrostSparkles", "IceCrack", "Shatter"):
                self.assertEqual(canonical(prepare.child(original_freeze, name)), canonical(prepare.child(prepare.child(effects, "FreezeEffects"), name)))
            for tree in (gun, pad, effects):
                self.assertFalse(any(i.get("class") in ("Script", "LocalScript", "ModuleScript", "RemoteEvent", "RemoteFunction", "ManualWeld") for i in tree.iter("Item")))
            mesh = prepare.child(prepare.child(effects, "IceBlock"), "Mesh")
            self.assertIn("66876751", ET.tostring(mesh, encoding="unicode"))
            self.assertIn("66876766", ET.tostring(mesh, encoding="unicode"))

if __name__ == "__main__":
    unittest.main()
