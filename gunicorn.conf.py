# gunicorn reads this from the working directory. The settings live in
# server/gunicorn.conf.py so hosts that run from server/ get the same ones.
import pathlib
import runpy

_settings = runpy.run_path(
    str(pathlib.Path(__file__).resolve().parent / "server" / "gunicorn.conf.py"))
globals().update({k: v for k, v in _settings.items() if not k.startswith("_")})
