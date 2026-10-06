class ApiError(Exception):
    """Raised anywhere in a request to return a JSON error response."""

    def __init__(self, status, message):
        super().__init__(message)
        self.status = status
        self.message = message
