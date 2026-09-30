"""Validate failures translators can introduce without opening Godot."""
import csv
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('localisation', Path(__file__).resolve().parents[1] / 'tools/localisation.py')
localisation = importlib.util.module_from_spec(spec)
spec.loader.exec_module(localisation)


class CatalogueTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.original = localisation.ROOT
        localisation.ROOT = Path(self.directory.name)
        (localisation.ROOT / 'localisation').mkdir()

    def tearDown(self):
        localisation.ROOT = self.original
        self.directory.cleanup()

    def write(self, rows):
        with (localisation.ROOT / 'localisation/test.csv').open('w', encoding='utf-8', newline='') as stream:
            writer = csv.writer(stream)
            writer.writerow(['keys', 'en', 'fr', '_notes', '_source'])
            writer.writerows(rows)

    def test_quoted_unicode_and_reordered_parameters(self):
        self.write([['UI_TEST', '{name}, take {item}.\nPlease.', 'Prenez {item}, {name}.\nMerci.', 'A "quote"', '']])
        self.assertIn('UI_TEST', localisation.catalogues())

    def test_duplicate_id(self):
        self.write([['UI_TEST','Hello','','',''], ['UI_TEST','Other','','','']])
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            localisation.catalogues()

    def test_missing_english(self):
        self.write([['UI_TEST','','Bonjour','','']])
        with self.assertRaisesRegex(ValueError, 'Missing English'):
            localisation.catalogues()

    def test_mismatched_argument(self):
        self.write([['UI_TEST','Hello {name}','Bonjour {nom}','','']])
        with self.assertRaisesRegex(ValueError, 'Placeholder mismatch'):
            localisation.catalogues()

    def test_plural_arguments(self):
        self.write([['UI_TEST','{count} guest','{count} invité','',''], ['', '{count} guests','invités','','']])
        with self.assertRaisesRegex(ValueError, 'Plural placeholder mismatch'):
            localisation.catalogues()


if __name__ == '__main__':
    unittest.main()
