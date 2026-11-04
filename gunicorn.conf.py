# Read automatically by gunicorn from the working directory, so hosts that
# run `gunicorn main:app` from the repo root (e.g. Pella) get these settings.
# Command-line flags (such as the host's --bind) still win.

# One process: SQLite and the model files belong to a single instance, and
# the models (~1 GB in memory) load once. Threads serve concurrent requests;
# model runs are serialised inside the app.
workers = 1
worker_class = "gthread"
threads = 4

# An upload is read by the model inside the request (about 7 s on 4 CPUs,
# longer on small plans); the default 30 s would kill slow ones.
timeout = 180

# Run main.py's boot steps (tables, first admin, model download) once in the
# master, where gunicorn's worker timeout doesn't apply.
preload_app = True


def post_worker_init(worker):
    """Read anything queued while the model was missing, in the background."""
    import threading

    from app.worker import drain_queue

    threading.Thread(target=drain_queue, args=(worker.app.wsgi(),), daemon=True).start()
