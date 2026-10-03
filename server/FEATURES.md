# Backend feature list

Ordered build list for the Flask backend described in `../DOCUMENTATION.md`.
Database is SQLite. Tick an item when it is implemented **and** covered by a test.

Defaults taken for the open decisions (change here if they are wrong):
one doctor per case; only the admin uploads; the doctor sees the model result
while reviewing; chat is out of scope.

## Phase 1 — Skeleton and login

- [x] 1. App factory, config from environment, SQLite database, JSON error responses, CORS for the Flutter web app
- [x] 2. Database tables: users, patients, cases, predictions, reviews, marks, disease_tags, model_feedback, test_requests, audit_log
- [x] 3. CLI: `init-db`, `create-user`, `seed` (one admin, two doctors for development)
- [x] 4. `POST /auth/login` — email + password, returns a JWT with role
- [x] 5. `GET /auth/me`; role checks on every route; a deactivated user's token stops working
- [x] 6. `GET /catalog` — verdicts, finding codes, disease tags, tests, urgencies, feedback kinds

## Phase 2 — Cases and assignment (admin)

- [x] 7. `GET/POST /admin/users`, `PATCH /admin/users/{id}` — list, create, deactivate doctors
- [x] 8. `POST /admin/cases` — upload PNG/JPEG with patient details; creates the case and a `queued` prediction
- [x] 9. `GET /admin/cases` with `status`, `doctor`, `flag` filters; `GET /admin/cases/{id}` with review and audit history
- [x] 10. `POST /admin/cases/assign` — assign and reassign, single or bulk
- [x] 11. Audit log entry for every creation, assignment and status change

## Phase 3 — Reviews (doctor)

- [x] 12. `GET /cases`, `GET /cases/{id}` — only my assigned cases; others return 404
- [x] 13. `GET /cases/{id}/image` and `/overlay` — served through the API, never as static files
- [x] 14. `PUT /cases/{id}/review` — save draft: marks, verdict, note, disease tags, model feedback, further testing
- [x] 15. `POST /cases/{id}/review/submit` — requires a verdict, locks the review
- [x] 16. Model feedback derived on submit when the verdict contradicts the model and the doctor left none

## Phase 4 — Closing the loop (admin)

- [x] 17. `POST /admin/cases/{id}/accept` and `/return` (note required; reopens the review for the same doctor)
- [x] 18. `GET /admin/export?kind=reviews|model_feedback` — CSV without patient name or hospital number
- [x] 19. `GET /admin/stats` — counts by status, per-doctor workload, model agreement rate

## Phase 5 — Model

- [x] 20. Lung segmentation model and classifier checkpoint in `models/`; single preprocessing module in `app/ml/preprocess.py`
- [x] 21. Worker (`flask worker`): takes `queued` predictions, runs mask → classifier, stores label and probability; `flask requeue` to re-run
- [ ] 22. Check worker output against `pipline/inference/predictions.csv` on known images — **blocked**: the original X-rays are not on this machine (only masks and heatmap renders), so the numbers have never been compared with the cluster's
- [x] 23. Grad-CAM heatmap saved per prediction and served by `/cases/{id}/overlay`

## Phase 6 — Hardening (not started)

- [ ] 24. DICOM upload: convert to PNG, strip patient tags
- [ ] 25. Schema migrations (Flask-Migrate) so the database can change without being recreated
- [ ] 26. Login rate limiting and password change endpoint
- [ ] 27. Production serving (gunicorn/waitress behind HTTPS), PostgreSQL option
