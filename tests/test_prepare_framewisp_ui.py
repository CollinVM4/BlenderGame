"""Preparation/CLI contracts using the real export plus isolated semantic fixtures."""
import base64
import contextlib
import importlib.util
import io
import re
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("prepare_framewisp", ROOT / "tools/prepare_framewisp_ui.py")
prep = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(prep)


def attribute(item, role):
    def string(value):
        data = value.encode()
        return struct.pack("<I", len(data)) + data
    # Include common Framewisp attributes before BlenderUI to test binary traversal.
    data = (struct.pack("<I", 3) + string("BB_DesignW") + b"\x06" + struct.pack("<d", 1920)
            + string("FW_Owned") + b"\x03\x01" + string("BlenderUI") + b"\x02" + string(role))
    props = item.find("Properties")
    old = props.find("BinaryString[@name='AttributesSerialize']")
    if old is not None:
        props.remove(old)
    ET.SubElement(props, "BinaryString", name="AttributesSerialize").text = base64.b64encode(data).decode()


def name(item, value):
    item.find("./Properties/string[@name='Name']").text = value


class PreparationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="framewisp-preparation-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / "new export.rbxmx"
        self.source.write_bytes((ROOT / "Framewisp_CCWMF.rbxmx").read_bytes())
        self.tree = ET.parse(self.source)
        actions = next(i for i in self.tree.iter("Item") if prep.item_name(i) == "FramewispActions")
        source = actions.find("./Properties/ProtectedString[@name='Source']")
        source.text = re.sub(re.escape(prep.BEGIN) + r".*?" + re.escape(prep.END) + r"\n?", "", source.text, flags=re.S)
        source.text = source.text.replace("\tif blenderMenus.Wire(btn) then return end\n", "")
        self.desktop = next(i for i in self.tree.iter("Item") if prep.item_name(i) == "Be a Blender! Desktop")
        self.content = next((i for i in self.desktop.findall("Item")
                             if prep.item_name(i) in ("DesktopContent", "Be a Blender! DesktopContent")), self.desktop)
        self.panels = {prep.item_name(i).removesuffix("_panel"): i for i in self.content.findall("Item")
                       if prep.item_name(i).removesuffix("_panel") in prep.PANELS}
        for panel in self.panels.values():
            panel.find("./Properties/bool[@name='Visible']").text = "true"
        self.save()

    def save(self):
        self.tree.write(self.source, encoding="utf-8")

    def prepare(self):
        warning = io.StringIO()
        with contextlib.redirect_stderr(warning), contextlib.redirect_stdout(io.StringIO()):
            prep.prepare(self.source)
        return ET.parse(self.source), warning.getvalue()

    def assert_hidden(self, tree):
        refs = {i.attrib["referent"] for i in self.panels.values()}
        for item in tree.iter("Item"):
            if item.attrib.get("referent") in refs:
                self.assertEqual(item.findtext("./Properties/bool[@name='Visible']"), "false")

    def test_named_panels_hidden_and_other_properties_preserved(self):
        before = ET.parse(self.source)
        after, warnings = self.prepare()
        self.assert_hidden(after)
        self.assertNotIn("Warning", warnings)
        actions = next(i for i in after.iter("Item") if prep.item_name(i) == "FramewispActions")
        self.assertIn("local blenderMenus = menus.Attach(gui, player)", actions.findtext("./Properties/ProtectedString[@name='Source']"))
        for old, new in zip(before.iter("Item"), after.iter("Item")):
            if old.attrib["referent"] in {i.attrib["referent"] for i in self.panels.values()}:
                old.find("./Properties/bool[@name='Visible']").text = "false"
            if prep.item_name(old) == "FramewispActions":
                old.find("./Properties/ProtectedString[@name='Source']").text = new.findtext("./Properties/ProtectedString[@name='Source']")
            self.assertEqual(ET.tostring(old.find("Properties")), ET.tostring(new.find("Properties")))

    def test_canvasgroup_and_renamed_semantic_wrappers(self):
        attribute(self.desktop, "Desktop")
        name(self.desktop, "New desktop")
        if self.content is self.desktop:
            wrapper = ET.SubElement(self.desktop, "Item", {"class": "CanvasGroup", "referent": "CONTENT_FIXTURE"})
            props = ET.SubElement(wrapper, "Properties")
            ET.SubElement(props, "string", name="Name").text = "New content"
            for item in list(self.desktop.findall("Item")):
                if item is not wrapper:
                    self.desktop.remove(item)
                    wrapper.append(item)
            self.content = wrapper
        attribute(self.content, "Content")
        name(self.content, "New content")
        for panel, item in self.panels.items():
            attribute(item, "Panel:" + panel)
            name(item, "Window " + panel)
            item.set("class", "CanvasGroup")
        self.save()
        after, warnings = self.prepare()
        self.assert_hidden(after)
        self.assertNotIn("Warning", warnings)

    def test_semantics_override_names_and_top_is_protected(self):
        attribute(self.panels["Index"], "Persistent")
        top = next(i for i in self.content.findall("Item") if prep.item_name(i) == "TOP")
        attribute(top, "Panel:Index")  # Even an accidental tag must never hide TOP.
        self.save()
        after, warning = self.prepare()
        for item in after.iter("Item"):
            if prep.item_name(item) in ("TOP", prep.item_name(self.panels["Index"])):
                self.assertEqual(item.findtext("./Properties/bool[@name='Visible']"), "true")
        self.assertIn("persistent target", warning)

    def test_missing_and_ambiguous_panel_warn_without_guessing(self):
        name(self.panels["Settings"], "Unknown settings")
        duplicate = ET.fromstring(ET.tostring(self.panels["Index"]))
        duplicate.set("referent", "DUPLICATE")
        self.content.append(duplicate)
        self.save()
        after, warning = self.prepare()
        self.assertIn("Settings: missing", warning)
        self.assertIn("Index: ambiguous", warning)
        for item in after.iter("Item"):
            if prep.item_name(item) in ("Unknown settings", prep.item_name(duplicate)):
                self.assertEqual(item.findtext("./Properties/bool[@name='Visible']"), "true")
        self.assertEqual(next(i for i in after.iter("Item") if prep.item_name(i) == prep.item_name(self.panels["Shop"])).findtext("./Properties/bool[@name='Visible']"), "false")

    def test_ambiguous_content_leaves_panels_unchanged(self):
        for index in range(2):
            item = ET.SubElement(self.desktop, "Item", {"class": "Frame", "referent": f"CONTENT{index}"})
            props = ET.SubElement(item, "Properties")
            ET.SubElement(props, "string", name="Name").text = "DesktopContent"
        self.save()
        after, warning = self.prepare()
        self.assertIn("ambiguous Content", warning)
        refs = {item.attrib["referent"] for item in self.panels.values()}
        for item in after.iter("Item"):
            if item.attrib["referent"] in refs:
                self.assertEqual(item.findtext("./Properties/bool[@name='Visible']"), "true")

    def test_unsupported_content_class_leaves_panels_unchanged(self):
        if self.content is not self.desktop:
            self.content.set("class", "Folder")
        else:
            wrapper = ET.SubElement(self.desktop, "Item", {"class": "Folder", "referent": "BAD_CONTENT"})
            props = ET.SubElement(wrapper, "Properties")
            ET.SubElement(props, "string", name="Name").text = "DesktopContent"
        self.save()
        _, warning = self.prepare()
        self.assertIn("unsupported Content class", warning)

    def test_missing_desktop_warns(self):
        name(self.desktop, "Unknown desktop")
        self.save()
        _, warning = self.prepare()
        self.assertIn("Desktop identifier, found 0", warning)

    def test_nested_unrelated_panel_untouched(self):
        duplicate = ET.fromstring(ET.tostring(self.panels["Index"]))
        duplicate.set("referent", "DECORATION")
        self.panels["Shop"].append(duplicate)
        self.save()
        after, _ = self.prepare()
        item = next(i for i in after.iter("Item") if i.attrib["referent"] == "DECORATION")
        self.assertEqual(item.findtext("./Properties/bool[@name='Visible']"), "true")

    def test_missing_visible_property_and_idempotency(self):
        props = self.panels["Index"].find("Properties")
        props.remove(props.find("bool[@name='Visible']"))
        self.save()
        after, _ = self.prepare()
        self.assert_hidden(after)
        first = self.source.read_bytes()
        self.prepare()
        self.assertEqual(first, self.source.read_bytes())

    def test_malformed_attributes_warn_and_skip(self):
        attribute(self.desktop, "Desktop")
        self.desktop.find("./Properties/BinaryString[@name='AttributesSerialize']").text = "bad data!"
        self.save()
        _, warning = self.prepare()
        self.assertIn("cannot read BlenderUI", warning)


class CLITests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="framewisp-cli-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "tools").mkdir()
        self.script = self.root / "tools/prepare_framewisp_ui.py"
        shutil.copyfile(ROOT / "tools/prepare_framewisp_ui.py", self.script)
        self.default = self.root / "Framewisp_CCWMF.rbxmx"
        shutil.copyfile(ROOT / "Framewisp_CCWMF.rbxmx", self.default)

    def cli(self, *args):
        return subprocess.run([sys.executable, str(self.script), *map(str, args)], cwd=self.root,
                              capture_output=True, text=True)

    def test_default_and_legacy_invocations(self):
        result = self.cli()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(str(self.default.resolve()), result.stdout)
        first = self.default.read_bytes()
        self.assertEqual(self.cli(self.default).returncode, 0)
        self.assertEqual(first, self.default.read_bytes())

    def test_custom_relative_and_absolute_input_preserves_original(self):
        for absolute in (False, True):
            source = self.root / "new export.rbxmx"
            shutil.copyfile(self.default, source)
            original = source.read_bytes()
            result = self.cli("--input", source if absolute else source.name)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn(str(self.default.resolve()), result.stdout)
            self.assertEqual(source.read_bytes(), original)

    def test_custom_output(self):
        original = self.default.read_bytes()
        result = self.cli("--input", self.default, "--output", "prepared_export.rbxmx")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.root / "prepared_export.rbxmx").is_file())
        self.assertEqual(self.default.read_bytes(), original)

    def test_cli_errors_leave_input_untouched(self):
        original = self.default.read_bytes()
        cases = [(('--input', 'missing.rbxmx'), 'does not exist'),
                 (('--input', 'design.rbxm'), '.rbxmx'),
                 (('--input', self.default, '--output', self.default), 'must differ'),
                 ((self.default, '--input', self.default), 'either'),
                 (('--output', 'out.rbxm'), '.rbxmx'),
                 (('--output', 'missing/out.rbxmx'), 'No such file')]
        for args, message in cases:
            with self.subTest(args=args):
                result = self.cli(*args)
                self.assertEqual(result.returncode, 2)
                self.assertIn(message, result.stderr)
                self.assertNotIn('Traceback', result.stderr)
                self.assertEqual(self.default.read_bytes(), original)

    def test_invalid_xml_and_wiring_report_useful_errors(self):
        bad = self.root / "bad.rbxmx"
        for data, message in (("<roblox>", "no element found"), ("<roblox/>", "FramewispActions")):
            bad.write_text(data)
            result = self.cli("--input", bad)
            self.assertEqual(result.returncode, 2)
            self.assertIn(message, result.stderr)


if __name__ == "__main__":
    unittest.main()
