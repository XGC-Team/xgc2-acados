import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

spec=importlib.util.spec_from_file_location('patch',Path(__file__).with_name('lazy_plot_exports.py'))
patch=importlib.util.module_from_spec(spec);spec.loader.exec_module(patch)

class HeadlessExports(unittest.TestCase):
 def test_headless_import_and_explicit_plot_call_are_separate(self):
  with tempfile.TemporaryDirectory() as directory:
   package=Path(directory)/'sample';package.mkdir()
   init=package/'__init__.py';init.write_text('AcadosModel = object\nfrom .plot_utils import plot_trajectories, latexify_plot\n')
   (package/'plot_utils.py').write_text('raise ImportError("plot backend is optional")\n')
   patch.make_plot_exports_lazy(init)
   original=init.read_text();patch.make_plot_exports_lazy(init);self.assertEqual(original,init.read_text())
   env=dict(os.environ,PYTHONPATH=directory)
   result=subprocess.run([sys.executable,'-c','from sample import AcadosModel; assert AcadosModel is object'],env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,universal_newlines=True)
   self.assertEqual(result.returncode,0,result.stderr)
   result=subprocess.run([sys.executable,'-c','from sample import plot_trajectories; plot_trajectories()'],env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,universal_newlines=True)
   self.assertNotEqual(result.returncode,0);self.assertIn('plot backend is optional',result.stderr)
   (package/'plot_utils.py').write_text('def plot_trajectories(*args, **kwargs): return args, kwargs\ndef latexify_plot(): return 7\n')
   result=subprocess.run([sys.executable,'-c','from sample import plot_trajectories, latexify_plot; assert plot_trajectories(1, label="x") == ((1,), {"label":"x"}); assert latexify_plot() == 7'],env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,universal_newlines=True)
   self.assertEqual(result.returncode,0,result.stderr)

if __name__=='__main__':unittest.main()
