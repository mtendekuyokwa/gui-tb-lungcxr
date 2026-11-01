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
  static const resetAdjustments = "Reset adjustments";
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
  static const chat = "Assistant";
  static const chatEmpty = "Ask a question about this X-ray.";
  static const chatHint = "Type a message";
  static const send = "Send";
  static const chatModelOffline =
      "The TB model isn't connected yet, so I can't answer questions about this X-ray.";
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
  static const hospitalNumber = "Hospital number (optional)";
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
  static const dashboardClear = "All clear";
  static const statsOpen = "Open";
  static const statsSubmitted = "Submitted";
  static const statsAccepted = "Accepted";
  static const statsAgreement = "Model agreement";
  static const statsWaiting = "Readings waiting on the model";
  static const export = "Export";
  static const exportReviews = "Reviews CSV";
  static const exportFeedback = "Model feedback CSV";
  static const exportCopied = "rows copied to clipboard";
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
  static const detailTab = "Case";
  static const intakeTab = "Intake";
  static const peopleTab = "People";
  static const insightsTab = "Insights";
  static const workloadQuestion = "Who holds the open work?";
  static const queueQuestion = "Where is the queue piling up?";
  static const chartTapDoctor = "Tap a doctor's bar to show only their cases";
  static const chartTapStatus = "Tap a slice to filter the case list";
  static const chartsTopDoctors = "Showing the 8 busiest doctors";
  static const statsDeferred =
      "Statistics are unavailable right now — the stats endpoint failed. "
      "The case list below still works; try Refresh.";
  static const dashboardFilterOn = "Filtering";

  static const String somethingWentWrong =
      "Something Went Wrong. Please try again later.";

  static String enterPassword = "Enter password";

  static String tamaraBandaemail = "tbanda@mwaiwathu.com";
}
