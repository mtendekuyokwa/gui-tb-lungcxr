# Frontend feature list

Ordered build list for the Flutter app described in `DOCUMENTATION.md`.
The backend's list is `server/FEATURES.md`. Tick an item when it is
implemented **and** covered by a test.

## Phase 1 — Connection and login

- [x] 1. API client (`lib/api/`): JSON requests, bearer token, error messages from the backend, base URL from `--dart-define=API_BASE_URL`
- [x] 2. Models parsed from the backend: user, catalog, case, prediction, review
- [x] 3. Session state: sign in, sign out, automatic sign-out when the token is rejected
- [x] 4. Login screen
- [x] 5. Role gate: doctor opens the review workspace, admin opens the admin workspace

## Phase 2 — Doctor workspace

- [x] 6. Case list loaded from the backend (replaces the two hard-coded patients), with status per case
- [x] 7. X-ray loaded from the backend with the user's token
- [x] 8. Marks restored from the saved draft, and autosaved as they change
- [x] 9. Review panel: verdict, disease tags, notes, "was the model wrong?", further testing with urgency
- [x] 10. Submit review; the case and its marks become read-only afterwards
- [x] 11. Return note from the admin shown when a case comes back
- [x] 12. Model reading badge: awaiting / TB suspected / Normal with probability
- [x] 13. XAI switch overlays the heatmap from the model worker

## Phase 3 — Admin workspace

- [x] 14. Case list with status filter and flags for "model wrong" and "needs testing"
- [x] 15. Upload a new case (PNG or JPEG) with patient name and hospital number
- [x] 16. Tick cases and assign or reassign them to a doctor
- [x] 17. Open a case: image, model reading and the doctor's review
- [x] 18. Accept a submitted review, or return it with a note

## Phase 4 — Not started

- [ ] 19. Keep the session across a page reload (token is in memory only today)
- [ ] 20. Admin: create and deactivate doctors
- [ ] 21. Admin: export CSV and statistics screen
- [ ] 22. Admin: filter by doctor and by flag; due dates
- [ ] 23. Segment tool wired to the backend lung mask (needs the model worker)
- [ ] 24. Assistant chat: connect to a language model or remove the tab
- [ ] 25. Narrow-screen layout for tablets and phones
