import 'dart:core';

class Strings {
  // General error string
  static const String Segmentation = "Segment";
  static const String Tools = "Tools";
  static const String EditImage = "Filter";
  static const String Brightness = "Brightness";
  static const String Contrast = "Contrast";
  static const String Hue = "Hue";
  static const String Saturation = "Saturation";
  static const String ZoomIn = "ZoomIn";
  static const String Zoomout = "Zoomout";
  static const String Save = "Save";
  static const Patient = "Patients";
  static const fakeName = "Lindiwe msasa";
  static const fakeName1 = "John mbinga";
  static const mark = "Mark";
  static const appName = "Kazuni Lungcxr";
  static const adjust = "Adjust";
  static const pan = "Pan";
  static const reset = "Reset";
  static const undo = "Undo";
  static const clearMarks = "Clear marks";
  static const fitToScreen = "Fit to screen";
  static const segAwaitingModel =
      "The model hasn't made a lung mask for this image yet";
  static const segUnavailable = "No lung mask for this image";
  static const segClipped = "XAI clipped to the edited lungs";
  static const segmentBrush = "Brush";
  static const segmentPen = "Pen";
  static const segmentEraser = "Eraser";
  static const segmentWidth = "Stroke width";
  static const resetSegmentEdits = "Reset to model mask";
  static const maskEdits = "Mask edits";
  static const maskEditsAdded = "added";
  static const maskEditsRemoved = "removed";
  static const markHint = "Drag on the image to mark, then label the finding";
  static const clientId = "Client ID";
  static const name = "Name";
  static const result = "Result";
  static const awaitingModel = "Awaiting model";
  static const activateXai = "Activate XAI";
  static const imageLoadFailed = "Could not load X-ray image";
  static const labelMark = "Label this mark";
  static const editLabel = "Edit label";
  static const markNote = "Comment";
  static const markNoteHint = "Describe this finding";
  static const saveMark = "Save mark";
  static const deleteMark = "Delete mark";
  static const close = "Close";
  static const unlabelled = "Unlabelled";
  static const lesionCategory = "Category";
  static const lesionType = "Lesion type";
  static const lesionParenchymal = "Parenchymal";
  static const lesionPleural = "Pleural";
  static const lesionMediastinal = "Mediastinal / hilar";
  static const lesionOther = "Other";
  static const lesionConsolidation = "Consolidation";
  static const lesionCavity = "Cavity";
  static const lesionNodule = "Nodule";
  static const lesionMiliary = "Miliary pattern";
  static const lesionFibrosis = "Fibrosis";
  static const lesionCalcification = "Calcification";
  static const lesionEffusion = "Pleural effusion";
  static const lesionPleuralThickening = "Pleural thickening";
  static const lesionPneumothorax = "Pneumothorax";
  static const lesionHilarLymphadenopathy = "Hilar lymphadenopathy";
  static const lesionMediastinalWidening = "Mediastinal widening";
  static const lesionOtherFinding = "Other finding";
  // Session
  static const signIn = "Sign in";
  static const signOut = "Sign out";
  static const email = "Email";
  static const password = "Password";
  static const signInPrompt = "Sign in to review chest X-rays";
  static const serverUnreachable =
      "Cannot reach the server. Check that the backend is running.";
  static const refresh = "Refresh";
  static const retry = "Retry";
  static const none = "None";

  // Case status
  static const statusUnassigned = "Unassigned";
  static const statusAssigned = "Assigned";
  static const statusInReview = "In review";
  static const statusSubmitted = "Submitted";
  static const statusReturned = "Returned";
  static const statusAccepted = "Accepted";

  // Doctor
  static const noCases = "No cases are assigned to you";
  static const noCasesDetail =
      "Cases appear here once the hospital admin assigns them.";
  static const searchClients = "Search clients";
  static const searchClientsHint = "Name or client ID";
  static const noClientMatch = "No clients match this search";
  static const modelReading = "Model reading";
  static const modelFailed = "Model failed";
  static const modelTb = "TB suspected";
  static const modelNormal = "Normal";
  static const xaiUnavailable = "No XAI heatmap for this image yet";
  static const readOnly = "Read only: this review has been submitted";
  static const review = "Review";
  static const verdict = "Verdict";
  static const diseases = "Diseases suspected";
  static const notes = "Notes";
  static const notesHint = "What you see on this X-ray";
  static const modelWrong = "Was the model wrong?";
  static const modelWrongHint = "What the model got wrong";
  static const furtherTesting = "Further testing";
  static const urgency = "Urgency";
  static const submitReview = "Submit review";
  static const reviewSubmitted = "Review submitted";
  static const reviewSubmittedDetail =
      "The admin can now accept it or return it to you.";
  static const returnedByAdmin = "Returned by the admin";
  static const verdictRequired = "Choose a verdict to submit";
  static const diseaseRequired = "Tag at least one disease to submit";
  static const saveUnsaved = "Unsaved changes";
  static const saveSaving = "Saving…";
  static const saveSaved = "Draft saved";
  static const saveFailed = "Could not save";

  // Admin
  static const cases = "Cases";
  static const create = "Create";
  static const all = "All";
  static const noCasesAdmin = "No cases match this filter";
  static const waitingOnModel =
      "Some readings are still with the model worker — keep 'flask worker' running.";
  static const uploadCase = "New case";
  static const patientName = "Patient name";
  static const patientNameOrNumber =
      "Patient name (or hospital number, to reuse a patient)";
  static const patientReuse =
      "Pick a suggestion to reuse that patient's record";
  static const hospitalNumber = "Patient file number (optional)";
  static const chooseImage = "Choose X-ray (PNG or JPEG)";
  static const upload = "Upload";
  static const caseUploaded = "Case created";
  static const assign = "Assign";
  static const assignTo = "Assign to";
  static const selectCasesToAssign =
      "Tick open cases in the list, then pick a doctor.";
  static const tickedCases = "selected";
  static const tickedNowWith = "now with";
  static const tickedHidden = "under another filter";
  static const assignStale =
      "Some ticked cases are no longer open and were unticked. Check the selection and try again.";
  static const noDoctors = "No active doctors";
  static const casesAssigned = "Cases assigned";
  static const caseDetail = "Case";
  static const selectCase = "Select a case to see its review.";
  static const doctor = "Doctor";
  static const admin = "Admin";
  static const createUser = "New user";
  static const fullName = "Full name";
  static const userCreated = "User created";
  static const noReviewYet = "No review yet";
  static const marks = "Marks";
  static const accept = "Accept";
  static const returnToDoctor = "Return to doctor";
  static const returnNoteHint = "What should the doctor change?";
  static const flagModelWrong = "Model flagged wrong";
  static const flagNeedsTesting = "Needs further testing";
  static const flaggedByServer = "recorded automatically";
  static const doctors = "Doctors";
  static const deactivate = "Deactivate";
  static const reactivate = "Reactivate";
  static const userDeactivated = "User deactivated";
  static const userReactivated = "User reactivated";
  static const showInactive = "Show inactive";
  static const filterDoctor = "Doctor";
  static const filterFlag = "Flag";
  static const flagAll = "All flags";
  static const flagModelWrongShort = "Model wrong";
  static const flagNeedsTestingShort = "Needs testing";
  static const dueDate = "Due date (optional)";
  static const clearDueDate = "Clear";
  static const stats = "Statistics";
  static const dashboard = "Dashboard";
  static const statsOpen = "Open";
  static const statsSubmitted = "Submitted";
  static const statsAccepted = "Accepted";
  static const statsWaiting = "Readings waiting on the model";
  static const export = "Export";
  static const exportReviews = "Reviews CSV";
  static const exportFeedback = "Model feedback CSV";
  static const exportCopied = "rows copied to clipboard";
  static const exportSaved = "rows saved to";
  static const exportDownload = "Download";
  static const exportCopy = "Copy to clipboard";
  static const exportHint =
      "Downloads a .csv file that opens in Excel or Sheets. Patient names and hospital numbers are left out.";
  static const exportRows = "rows";
  static const xrayTab = "X-ray";
  static const casesTab = "Cases";
  static const reviewTab = "Review";
  static const manageTab = "Manage";

  // Admin dashboard
  static const searchCases = "Search cases";
  static const noCasesMatch = "No cases match this search";
  static const moreFilters = "More filters";
  static const fewerFilters = "Fewer filters";
  static const selectAllShown = "Select all shown";
  static const clearTicked = "Clear";
  static const adminNav = "Workspace";
  static const teamTab = "Team";
  static const detailTab = "Case";
  static const intakeTab = "Intake";
  // Dashboard: a work queue first, a report second.
  static const nothingWaits = "Nothing waits for you right now.";
  static const queueSignOff = "Waiting for your sign-off";
  static const queueOverdue = "Past due";
  static const queueUnassigned = "Not assigned";
  static const queueEmptySignOff = "No reviews to sign off";
  static const queueEmptyOverdue = "No case is past its due date";
  static const queueEmptyUnassigned = "Every case has a doctor";
  static const actionReview = "Review";
  static const actionAssign = "Assign";
  static const actionOpen = "Open";
  static const showAll = "Show all";
  static const waiting = "waiting";
  static const late = "late";
  static const uploaded = "uploaded";
  static const ago = "ago";
  static const justNow = "just now";
  static const minuteOne = "minute";
  static const minuteMany = "minutes";
  static const hourOne = "hour";
  static const hourMany = "hours";
  static const dayOne = "day";
  static const dayMany = "days";
  static const summarySignOffOne = "review waits for your sign-off.";
  static const summarySignOffMany = "reviews wait for your sign-off.";
  static const summaryOverdueOne = "case is past due.";
  static const summaryOverdueMany = "cases are past due.";
  static const summaryUnassignedOne = "case needs a doctor.";
  static const summaryUnassignedMany = "cases need a doctor.";
  static const summaryWithDoctorsOne = "case is with doctors.";
  static const summaryWithDoctorsMany = "cases are with doctors.";
  static const teamTitle = "Doctors";
  static const teamHint =
      "Fewest open cases first, so the next assignment is obvious";
  static const hasRoom = "Has room";
  static const noOpenCases = "No open cases";
  static const open = "open";
  static const oldest = "oldest";
  static const modelTitle = "Model";
  static const modelHint =
      "Compared on submitted reviews where both gave a TB or no-TB answer";
  static const agreed = "agreed with the model";
  static const agreeOf = "of";
  static const tooFewToJudge =
      "Too few reviews to judge yet. The rate shows from";
  static const reviews = "reviews";
  static const agreeLow = "Low";
  static const agreeHealthy = "Healthy";
  static const agreeNone = "No review to compare with the model yet";
  static const flaggedKinds = "How doctors flagged the model";
  static const reviewFlagged = "Review flagged cases";
  static const verdictMix = "Doctors' verdicts";
  static const noneYet = "None yet";
  static const chartsTopDoctors = "Showing 8 doctors";
  static const statsDeferred =
      "Statistics are unavailable right now — the stats endpoint failed. "
      "The Cases page still works; try Refresh.";

  static const String somethingWentWrong =
      "Something Went Wrong. Please try again later.";

  static String enterPassword = "Enter password";

  static String tamaraBandaemail = "tbanda@mwaiwathu.com";

  // Hospitals
  static const hospital = "Hospital";
  static const hospitals = "Hospitals";
  static const hospitalsSubtitle =
      "Where X-rays come from. Doctors can also add one while filing a case.";
  static const hospitalHint = "Hospital (optional)";
  static const hospitalHelp =
      "Type to find a hospital, or pick \"Create\" to add a new one.";
  static const hospitalChosen = "Hospital selected.";
  static const creatingHospital = "Adding hospital…";
  static String createHospitalNamed(String name) => 'Create "$name"';
  static const hospitalSearchOrAdd = "Find or name a hospital";
  static const addHospital = "Add";
  static const noHospitals = "No hospitals yet.";
  static const noHospitalMatch = "No hospital matches; add it.";

  // Uploading
  static const uploading = "Uploading…";

  // Case list
  static const hideCase = "Remove from my list";
  static const caseHidden = "Case removed from your list";
  static const caseHiddenDetail =
      "Nothing was deleted; the admin still sees it.";
  static const showCases = "Show cases";
  static const hideCaseList = "Collapse case list";
  static const resizeReview = "Resize review panel";

  // Segmentation re-evaluation
  static const reevaluate = "Re-evaluate";
  static const reevaluateTip =
      "Send the corrected lung mask to the model for a new reading";
  static const modelReadingNow = "Model reading…";
  static const reevaluateSent = "Sent for re-evaluation";
  static const reevaluateSentDetail =
      "The model is reading the X-ray with your corrected mask.";
  static const reevaluateFailed = "Could not re-evaluate";
  static const reevaluated = "Re-evaluated with your corrected mask";
  static const correctedMask = "corrected mask";
}
